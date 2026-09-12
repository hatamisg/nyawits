import ARKit
import AVFoundation
import Combine
import CoreImage
import CoreLocation
import CoreMotion
import Foundation
import ImageIO
import UIKit

@MainActor
final class PlantCaptureViewModel: NSObject, ObservableObject {
    let session = ARSession()
    let plan: MulchRowPlan
    let fieldID: UUID
    let fieldName: String

    @Published private(set) var observations: [PlantObservation]
    @Published private(set) var trackingQuality: PlantTrackingQuality = .unavailable
    @Published private(set) var trackingMessage = "Menyiapkan kamera…"
    @Published private(set) var latestLocation: CLLocation?
    @Published private(set) var isMotionStable = true
    @Published private(set) var isCapturing = false
    @Published private(set) var isCameraRunning = false
    @Published var selectedRowNumber = 1
    @Published var selectedSide: PlantCaptureSide = .left
    @Published var errorMessage: String?
    @Published private(set) var completedRowSides: [String] = []
    private var captureSessionID = UUID()
    private var positionEstimator = PlantPositionEstimator()
    private var locationHistory: [CLLocation] = []
    private var wantsToRun = false

    private let existingField: MappedField?
    private let fieldCreatedAt: Date
    private var baseRevisionID: UUID?
    private let locationManager = CLLocationManager()
    private var latestHeading: CLHeading?
    private let motionManager = CMMotionManager()
    private let imageContext = CIContext(options: [.cacheIntermediates: false])

    init(
        fieldID: UUID,
        fieldName: String,
        plan: MulchRowPlan,
        existingField: MappedField? = nil
    ) {
        self.fieldID = fieldID
        self.fieldName = fieldName
        self.plan = plan
        self.existingField = existingField
        fieldCreatedAt = existingField?.createdAt ?? Date()
        baseRevisionID = existingField?.mappingRevisionID
        observations = existingField?.observations ?? []
        super.init()
        completedRowSides = existingField?.completedRowSides ?? []
        let rowToResume = existingField?.resumeRowID ?? observations.last?.rowID
        selectedRowNumber = plan.rows.firstIndex(where: { $0.id == rowToResume }).map { $0 + 1 } ?? 1
        selectedSide = existingField?.resumeSide ?? observations.last?.side ?? .left

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .fitness
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.pausesLocationUpdatesAutomatically = false
        session.delegate = self
        session.delegateQueue = .main
    }

    var isCameraSupported: Bool {
        ARWorldTrackingConfiguration.isSupported
    }

    var currentRow: MulchRow? {
        guard plan.rows.indices.contains(selectedRowNumber - 1) else { return nil }
        return plan.rows[selectedRowNumber - 1]
    }

    var currentPlantSequence: Int {
        guard let row = currentRow else { return 1 }
        let latestSequence = observations
            .filter { $0.rowID == row.id && $0.side == selectedSide }
            .map(\.plantSequence)
            .max() ?? 0
        return latestSequence + 1
    }

    var capturedPlantCount: Int {
        observations.filter { $0.status == .captured }.count
    }

    var latestCapturedObservation: PlantObservation? {
        observations.last(where: { $0.status == .captured })
    }

    var locationStatus: String {
        if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
            return "Lokasi nonaktif"
        }
        guard let location = validLatestLocation else { return "Mencari lokasi" }
        if location.horizontalAccuracy <= 5 { return "Lokasi siap" }
        if location.horizontalAccuracy <= 15 { return "Lokasi perkiraan" }
        return "Lokasi lemah"
    }

    func start() async {
        // Canvas renders controls without requesting camera, GPS, or motion access.
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        guard !isCameraRunning else { return }
        wantsToRun = true
        startLocationUpdates()
        startMotionUpdates()

        guard isCameraSupported else {
            trackingMessage = "Pelacakan kamera memerlukan iPhone"
            return
        }

        let authorization = AVCaptureDevice.authorizationStatus(for: .video)
        let isAuthorized: Bool
        switch authorization {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }

        guard isAuthorized else {
            errorMessage = "Izinkan akses kamera di Pengaturan untuk memotret tanaman."
            return
        }
        guard wantsToRun, !Task.isCancelled else { return }

        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        configuration.isAutoFocusEnabled = true
        if let highResolutionFormat = ARWorldTrackingConfiguration
            .recommendedVideoFormatForHighResolutionFrameCapturing {
            configuration.videoFormat = highResolutionFormat
        }
        captureSessionID = UUID()
        positionEstimator.reset()
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isCameraRunning = true
    }

    func stop() {
        wantsToRun = false
        positionEstimator.reset()
        session.pause()
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        motionManager.stopDeviceMotionUpdates()
        isCameraRunning = false
    }

    func selectPreviousRow() {
        selectedRowNumber = max(1, selectedRowNumber - 1)
    }

    func selectNextRow() {
        selectedRowNumber = min(plan.rows.count, selectedRowNumber + 1)
    }

    func capture(using store: FieldMappingStore) async {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        guard isCameraRunning, !isCapturing, let row = currentRow else { return }
        let rowNumber = selectedRowNumber, side = selectedSide, sequence = currentPlantSequence
        let captureID = captureSessionID
        isCapturing = true
        defer { isCapturing = false }

        do {
            let frame = try await session.captureHighResolutionFrame()
            guard wantsToRun, captureSessionID == captureID else { return }
            let observationID = UUID()
            guard let imageData = jpegData(from: frame.capturedImage),
                  let filename = store.savePhoto(imageData, observationID: observationID) else {
                errorMessage = "Foto tidak dapat disiapkan atau disimpan."
                return
            }

            let observation = makeObservation(
                id: observationID,
                row: row,
                status: .captured,
                imageFilename: filename,
                frame: frame,
                rowNumber: rowNumber, side: side, sequence: sequence
            )
            observations.append(observation)
            if !persist(using: store) {
                observations.removeLast()
                store.deletePhoto(filename: filename)
                return
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            errorMessage = "Tanaman belum berhasil difoto. Tahan ponsel dan coba lagi."
        }
    }

    func skipCurrentPlant(using store: FieldMappingStore) {
        guard !isCapturing, let row = currentRow else { return }
        let observation = makeObservation(
            id: UUID(),
            row: row,
            status: .skipped,
            imageFilename: nil,
            frame: nil,
            rowNumber: selectedRowNumber, side: selectedSide, sequence: currentPlantSequence
        )
        observations.append(observation)
        if !persist(using: store) { observations.removeLast() }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func undoLast(using store: FieldMappingStore) {
        guard !isCapturing, let observation = observations.popLast() else { return }
        if persist(using: store) { store.deletePhoto(filename: observation.imageFilename) }
        else { observations.append(observation) }
    }

    func finish(using store: FieldMappingStore) -> Bool {
        guard !isCapturing, persist(using: store) else { return false }
        stop()
        return true
    }

    func saveProgress(using store: FieldMappingStore) { _ = persist(using: store) }

    var currentSideIsComplete: Bool {
        guard let row = currentRow else { return false }
        return completedRowSides.contains(MappedField.completionKey(rowID: row.id, side: selectedSide))
    }

    func toggleSideComplete(using store: FieldMappingStore) {
        guard !isCapturing, let row = currentRow else { return }
        let previous = completedRowSides
        let key = MappedField.completionKey(rowID: row.id, side: selectedSide)
        if currentSideIsComplete { completedRowSides.removeAll { $0 == key } }
        else { completedRowSides.append(key) }
        if !persist(using: store) { completedRowSides = previous }
    }

    var sideGuide: String {
        guard let row = currentRow else { return "" }
        return PlantSpatialReference.sideLabel(row: row, side: .left) + " • "
            + PlantSpatialReference.sideLabel(row: row, side: .right)
    }

    private var validLatestLocation: CLLocation? {
        guard let latestLocation,
              latestLocation.horizontalAccuracy >= 0,
              abs(latestLocation.timestamp.timeIntervalSinceNow) <= 15 else { return nil }
        return latestLocation
    }

    private func makeObservation(
        id: UUID,
        row: MulchRow,
        status: PlantObservationStatus,
        imageFilename: String?,
        frame: ARFrame?,
        rowNumber: Int, side: PlantCaptureSide, sequence: Int
    ) -> PlantObservation {
        let captureDate = frame.map { Date(timeIntervalSinceNow: $0.timestamp - ProcessInfo.processInfo.systemUptime) } ?? Date()
        let location = locationHistory.min(by: {
            abs($0.timestamp.timeIntervalSince(captureDate)) < abs($1.timestamp.timeIntervalSince(captureDate))
        }).flatMap { abs($0.timestamp.timeIntervalSince(captureDate)) <= 2 && $0.horizontalAccuracy >= 0 ? $0 : nil }
        let quality = frame.map { trackingQuality(for: $0.camera.trackingState) } ?? trackingQuality
        let transform = frame.map { flatten($0.camera.transform) } ?? []
        let estimate = positionEstimator.estimate(location: location, transform: transform,
            timestamp: frame?.timestamp ?? ProcessInfo.processInfo.systemUptime,
            trackingNormal: quality == .normal && frame != nil,
            headingAccurate: validHeadingDegrees != nil && (latestHeading?.headingAccuracy ?? 180) <= 15)
        let projection = estimate.flatMap {
            MulchRowGeometryCalculator.nearestRow(to: $0.coordinate, rows: [row])
        }
        // Don't force a position from another part of the field onto the chosen row.
        let acceptedProjection = projection.flatMap { $0.distanceMeters <= 10 ? $0 : nil }
        var observation = PlantObservation(
            id: id,
            fieldID: fieldID,
            rowID: row.id,
            rowNumber: rowNumber,
            plantSequence: sequence,
            side: side,
            status: status,
            capturedAt: captureDate,
            arFrameTimestamp: frame?.timestamp,
            imageFilename: imageFilename,
            location: location.map { GeoCoordinate($0.coordinate) },
            locationTimestamp: location?.timestamp,
            horizontalAccuracyMeters: location?.horizontalAccuracy,
            headingDegrees: validHeadingDegrees,
            headingAccuracyDegrees: latestHeading.flatMap {
                $0.headingAccuracy >= 0 ? $0.headingAccuracy : nil
            },
            projectedCoordinate: acceptedProjection.map { GeoCoordinate($0.coordinate) },
            rowProgress: acceptedProjection.map { PlantSpatialReference.canonicalProgress(row: row, coordinate: $0.coordinate) },
            distanceFromRowMeters: projection?.distanceMeters,
            cameraTransform: frame.map { flatten($0.camera.transform) } ?? [],
            cameraIntrinsics: frame.map { flatten($0.camera.intrinsics) } ?? [],
            trackingQuality: quality,
            motionWasStable: isMotionStable
        )
        observation.captureSessionID = captureSessionID
        observation.positionMethod = estimate?.method
        observation.positionUncertaintyMeters = estimate?.uncertainty
        observation.anchorCoordinate = estimate?.anchor.map { GeoCoordinate($0.location.coordinate) }
        observation.anchorCameraTransform = estimate?.anchor?.transform
        observation.anchorAccuracyMeters = estimate?.anchor?.location.horizontalAccuracy
        observation.anchorFrameTimestamp = estimate?.anchor?.frameTimestamp
        observation.sideReferenceVersion = 1
        observation.imageWidth = frame.map { CVPixelBufferGetHeight($0.capturedImage) }
        observation.imageHeight = frame.map { CVPixelBufferGetWidth($0.capturedImage) }
        observation.imageRotationDegrees = frame == nil ? nil : 90
        return observation
    }

    /// Simpan progress pada record terbaru di store: preservasi arsip/revision,
    /// tolak capture stale (field hilang atau revision berubah di luar layar).
    @discardableResult
    private func persist(using store: FieldMappingStore) -> Bool {
        let outcome = store.saveCapture(
            fieldID: fieldID,
            fieldName: fieldName,
            plan: plan,
            observations: observations,
            completedRowSides: completedRowSides,
            resumeRowID: currentRow?.id,
            resumeSide: selectedSide,
            fieldCreatedAt: fieldCreatedAt,
            baseRevisionID: baseRevisionID,
            allowsCreation: existingField == nil
        )
        switch outcome {
        case .success(let revisionID):
            baseRevisionID = revisionID ?? baseRevisionID
            return true
        case .failure(let error):
            errorMessage = Self.captureErrorMessage(for: error)
            return false
        }
    }

    private static func captureErrorMessage(for error: FieldStoreError) -> String {
        switch error {
        case .captureStale, .dataLoadFailed:
            "Pemetaan berubah di luar layar ini. Buka ulang kebun sebelum melanjutkan memotret."
        case .storageFailure:
            "Perubahan belum tersimpan. Periksa ruang penyimpanan lalu coba lagi."
        case .fieldNotFound, .invalidName, .invalidPlan, .revisionStale:
            "Perubahan belum tersimpan. Periksa ruang penyimpanan lalu coba lagi."
        }
    }

    private func jpegData(from pixelBuffer: CVPixelBuffer) -> Data? {
        let image = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return imageContext.jpegRepresentation(
            of: image,
            colorSpace: colorSpace,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.9]
        )
    }

    private func flatten(_ matrix: simd_float4x4) -> [Float] {
        [
            matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z, matrix.columns.0.w,
            matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z, matrix.columns.1.w,
            matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z, matrix.columns.2.w,
            matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z, matrix.columns.3.w
        ]
    }

    private func flatten(_ matrix: simd_float3x3) -> [Float] {
        [
            matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z,
            matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z,
            matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z
        ]
    }

    private func startLocationUpdates() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                locationManager.startUpdatingHeading()
            }
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    private var validHeadingDegrees: Double? {
        guard let latestHeading,
              latestHeading.headingAccuracy >= 0,
              abs(latestHeading.timestamp.timeIntervalSinceNow) <= 15 else { return nil }
        return latestHeading.trueHeading >= 0
            ? latestHeading.trueHeading
            : latestHeading.magneticHeading
    }

    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let rotation = motion.rotationRate
            let acceleration = motion.userAcceleration
            let rotationMagnitude = sqrt(rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z)
            let accelerationMagnitude = sqrt(
                acceleration.x * acceleration.x
                    + acceleration.y * acceleration.y
                    + acceleration.z * acceleration.z
            )
            Task { @MainActor [weak self] in
                self?.isMotionStable = rotationMagnitude < 0.65 && accelerationMagnitude < 0.14
            }
        }
    }

    private func trackingQuality(for state: ARCamera.TrackingState) -> PlantTrackingQuality {
        switch state {
        case .normal: .normal
        case .limited: .limited
        case .notAvailable: .unavailable
        }
    }
}

extension PlantCaptureViewModel: ARSessionDelegate {
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        trackingQuality = trackingQuality(for: camera.trackingState)
        if trackingQuality != .normal { positionEstimator.reset() }
        switch camera.trackingState {
        case .normal:
            trackingMessage = "Posisi siap"
        case let .limited(reason):
            switch reason {
            case .initializing:
                trackingMessage = "Gerakkan ponsel perlahan"
            case .excessiveMotion:
                trackingMessage = "Kurangi gerakan"
            case .insufficientFeatures:
                trackingMessage = "Arahkan ke seluruh tanaman"
            case .relocalizing:
                trackingMessage = "Memulihkan posisi"
            @unknown default:
                trackingMessage = "Posisi kurang akurat"
            }
        case .notAvailable:
            trackingMessage = "Posisi tidak tersedia"
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        errorMessage = "Pelacakan kamera terhenti. Tutup lalu buka kembali layar ini."
        trackingQuality = .unavailable
        isCameraRunning = false
        positionEstimator.reset()
    }

    func sessionWasInterrupted(_ session: ARSession) {
        positionEstimator.reset()
        trackingQuality = .unavailable
        isCameraRunning = false
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        guard wantsToRun else { return }
        Task { await start() }
    }
}

extension PlantCaptureViewModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        latestLocation = locations.last
        locationHistory.append(contentsOf: locations)
        locationHistory = locationHistory.filter { abs($0.timestamp.timeIntervalSinceNow) < 20 }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        latestHeading = newHeading
    }
}
