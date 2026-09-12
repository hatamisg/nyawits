import CoreLocation
import Foundation

struct GeoCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// Tipe nilai murni: `nonisolated` supaya bisa dipakai lapisan presentasi dan
// kalkulator yang sengaja tidak terikat MainActor.
nonisolated enum PlantCaptureSide: String, Codable, CaseIterable, Identifiable {
    case left
    case right

    var id: Self { self }

    var title: String {
        switch self {
        case .left: "Sisi A"
        case .right: "Sisi B"
        }
    }
}

enum PlantObservationStatus: String, Codable {
    case captured
    case skipped
}

enum PlantTrackingQuality: String, Codable {
    case normal
    case limited
    case unavailable
}

struct MappedRow: Codable, Equatable, Identifiable {
    let id: UUID
    let number: Int
    let pointA: GeoCoordinate
    let pointB: GeoCoordinate

    init(row: MulchRow, number: Int) {
        id = row.id
        self.number = number
        pointA = GeoCoordinate(row.pointA)
        pointB = GeoCoordinate(row.pointB)
    }

    var mulchRow: MulchRow {
        MulchRow(id: id, pointA: pointA.coordinate, pointB: pointB.coordinate)
    }
}

struct PlantObservation: Codable, Equatable, Identifiable {
    let id: UUID
    let fieldID: UUID
    let rowID: UUID
    let rowNumber: Int
    let plantSequence: Int
    let side: PlantCaptureSide
    let status: PlantObservationStatus
    let capturedAt: Date
    let arFrameTimestamp: TimeInterval?
    let imageFilename: String?
    let location: GeoCoordinate?
    let locationTimestamp: Date?
    let horizontalAccuracyMeters: Double?
    let headingDegrees: Double?
    let headingAccuracyDegrees: Double?
    let projectedCoordinate: GeoCoordinate?
    let rowProgress: Double?
    let distanceFromRowMeters: Double?
    let cameraTransform: [Float]
    let cameraIntrinsics: [Float]
    let trackingQuality: PlantTrackingQuality
    let motionWasStable: Bool
    // Optional additions keep existing on-device JSON readable.
    var captureSessionID: UUID? = nil
    var positionMethod: String? = nil
    var anchorCoordinate: GeoCoordinate? = nil
    var anchorCameraTransform: [Float]? = nil
    var anchorAccuracyMeters: Double? = nil
    var anchorFrameTimestamp: TimeInterval? = nil
    var positionUncertaintyMeters: Double? = nil
    var imageWidth: Int? = nil
    var imageHeight: Int? = nil
    var imageRotationDegrees: Int? = nil
    var sideReferenceVersion: Int? = nil
    // KOLOM LAMA. Jangan dihapus dan jangan ditulis oleh kode baru.
    //
    // Dulu app menampilkan angka ini sebagai "NDRE", padahal tidak ada yang
    // pernah mengukurnya: satu-satunya penulisnya VigorDemoFactory, yang
    // menandai dirinya "simulated". Keduanya tetap DIBACA supaya JSON yang
    // sudah ada di perangkat tetap terbuka -- menghapus field akan membuat
    // decode gagal, dan FieldMappingStore menyetel dataLoadFailed yang
    // memblokir SELURUH mutasi.
    //
    // Pengukuran sungguhan tidak tinggal di sini: skor vigor adalah properti
    // SESI, bukan properti satu foto, jadi ia hidup di ScanSession.
    var ndre: Double? = nil
    var ndreSource: String? = nil
}

/// Snapshot riwayat pemetaan untuk satu revisi geometri kebun.
/// Nonrekursif: tidak menyimpan seluruh field atau arsip bersarang.
struct ArchivedFieldMapping: Codable, Equatable {
    let revisionID: UUID
    let archivedAt: Date
    let nameAtArchive: String
    let boundaryID: UUID
    let boundaryPoints: [GeoCoordinate]
    let areaSquareMeters: Double
    let perimeterMeters: Double
    let rotationDegrees: Double
    let rows: [MappedRow]
    let observations: [PlantObservation]
    let completedRowSides: [String]?
    let resumeRowID: UUID?
    let resumeSide: PlantCaptureSide?
    /// Tanggal versi yang diarsipkan mulai dipakai.
    let createdAt: Date

    init(
        revisionID: UUID,
        archivedAt: Date,
        nameAtArchive: String,
        boundaryID: UUID,
        boundaryPoints: [GeoCoordinate],
        areaSquareMeters: Double,
        perimeterMeters: Double,
        rotationDegrees: Double,
        rows: [MappedRow],
        observations: [PlantObservation],
        completedRowSides: [String]?,
        resumeRowID: UUID?,
        resumeSide: PlantCaptureSide?,
        createdAt: Date
    ) {
        self.revisionID = revisionID
        self.archivedAt = archivedAt
        self.nameAtArchive = nameAtArchive
        self.boundaryID = boundaryID
        self.boundaryPoints = boundaryPoints
        self.areaSquareMeters = areaSquareMeters
        self.perimeterMeters = perimeterMeters
        self.rotationDegrees = rotationDegrees
        self.rows = rows
        self.observations = observations
        self.completedRowSides = completedRowSides
        self.resumeRowID = resumeRowID
        self.resumeSide = resumeSide
        self.createdAt = createdAt
    }

    init(snapshotOf field: MappedField, revisionID: UUID, archivedAt: Date, versionCreatedAt: Date) {
        self.init(
            revisionID: revisionID,
            archivedAt: archivedAt,
            nameAtArchive: field.name,
            boundaryID: field.boundaryID,
            boundaryPoints: field.boundaryPoints,
            areaSquareMeters: field.areaSquareMeters,
            perimeterMeters: field.perimeterMeters,
            rotationDegrees: field.rotationDegrees,
            rows: field.rows,
            observations: field.observations,
            completedRowSides: field.completedRowSides,
            resumeRowID: field.resumeRowID,
            resumeSide: field.resumeSide,
            createdAt: versionCreatedAt
        )
    }
}

struct MappedField: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    // Geometri/rows versi aktif; hanya diubah lewat transaksi updateField.
    var boundaryID: UUID
    var boundaryPoints: [GeoCoordinate]
    var areaSquareMeters: Double
    var perimeterMeters: Double
    var rotationDegrees: Double
    var rows: [MappedRow]
    var observations: [PlantObservation]
    var isDemo: Bool? = nil
    var completedRowSides: [String]? = nil
    var resumeRowID: UUID? = nil
    var resumeSide: PlantCaptureSide? = nil
    // Optional revision/history: legacy nil berarti versi awal tanpa history.
    var mappingRevisionID: UUID? = nil
    var mappingVersionCreatedAt: Date? = nil
    var archivedMappings: [ArchivedFieldMapping]? = nil

    init(
        id: UUID = UUID(),
        name: String,
        plan: MulchRowPlan,
        observations: [PlantObservation] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        boundaryID = plan.boundary.id
        boundaryPoints = plan.boundary.points.map { GeoCoordinate($0.coordinate) }
        areaSquareMeters = plan.boundary.areaSquareMeters
        perimeterMeters = plan.boundary.perimeterMeters
        rotationDegrees = plan.rotationDegrees
        rows = plan.rows.enumerated().map { MappedRow(row: $0.element, number: $0.offset + 1) }
        self.observations = observations
    }

    var plan: MulchRowPlan {
        let boundary = FieldBoundary(
            id: boundaryID,
            points: boundaryPoints.map { BoundaryPoint(coordinate: $0.coordinate) },
            areaSquareMeters: areaSquareMeters,
            perimeterMeters: perimeterMeters
        )
        return MulchRowPlan(
            boundary: boundary,
            rows: rows.map(\.mulchRow),
            rotationDegrees: rotationDegrees
        )
    }

    var capturedPlantCount: Int {
        observations.filter { $0.status == .captured }.count
    }

    var mappedRowCount: Int {
        Set(observations.filter { $0.status == .captured }.map(\.rowID)).count
    }

    var lowConfidenceCount: Int {
        observations.filter {
            $0.status == .captured
                && $0.projectedCoordinate != nil
                && (($0.positionUncertaintyMeters ?? $0.horizontalAccuracyMeters ?? .infinity) > 10 || $0.trackingQuality != .normal)
        }.count
    }

    var unpositionedPhotoCount: Int {
        observations.filter {
            $0.status == .captured && $0.projectedCoordinate == nil
        }.count
    }

    var completionFraction: Double {
        guard !rows.isEmpty else { return 0 }
        let validKeys = Set(rows.flatMap { row in
            PlantCaptureSide.allCases.map { Self.completionKey(rowID: row.id, side: $0) }
        })
        return Double(Set(completedRowSides ?? []).intersection(validKeys).count) / Double(rows.count * 2)
    }

    static func completionKey(rowID: UUID, side: PlantCaptureSide) -> String {
        "\(rowID.uuidString):\(side.rawValue)"
    }

    /// Nilai pratinjau dari kolom lama `ndre`. Hanya kebun demo yang punya isi;
    /// kebun nyata selalu kosong, karena capture tidak pernah menulis kolom itu.
    var previewVigorValues: [Double] {
        observations.compactMap(\.ndre).filter { $0.isFinite && (0...1).contains($0) }
    }
}

extension ArchivedFieldMapping {
    /// Plan versi arsip untuk tampilan riwayat hanya-baca.
    var plan: MulchRowPlan {
        let boundary = FieldBoundary(
            id: boundaryID,
            points: boundaryPoints.map { BoundaryPoint(coordinate: $0.coordinate) },
            areaSquareMeters: areaSquareMeters,
            perimeterMeters: perimeterMeters
        )
        return MulchRowPlan(
            boundary: boundary,
            rows: rows.map(\.mulchRow),
            rotationDegrees: rotationDegrees
        )
    }

    var capturedPhotoCount: Int {
        observations.filter { $0.status == .captured }.count
    }
}

/// Perbandingan geometri semantik antar plan, tanpa memandang ID instance editor.
/// Toleransi koordinat 1e-9 derajat (±0,1 mm di ekuator) dan rotasi 1e-6 derajat:
/// menoleransi noise floating-point GPS/editor tanpa mengabaikan perubahan material.
enum FieldGeometryComparator {
    static let toleranceDegrees: Double = 1e-9
    static let toleranceRotationDegrees: Double = 1e-6

    static func isEquivalent(_ lhs: MulchRowPlan, _ rhs: MulchRowPlan) -> Bool {
        guard lhs.boundary.points.count == rhs.boundary.points.count else { return false }
        for (index, point) in lhs.boundary.points.enumerated() {
            guard isClose(point.coordinate, rhs.boundary.points[index].coordinate) else { return false }
        }
        guard lhs.rows.count == rhs.rows.count else { return false }
        for (index, row) in lhs.rows.enumerated() {
            guard isClose(row.pointA, rhs.rows[index].pointA),
                  isClose(row.pointB, rhs.rows[index].pointB) else { return false }
        }
        return abs(lhs.rotationDegrees - rhs.rotationDegrees) <= toleranceRotationDegrees
    }

    private static func isClose(
        _ lhs: CLLocationCoordinate2D,
        _ rhs: CLLocationCoordinate2D
    ) -> Bool {
        abs(lhs.latitude - rhs.latitude) <= toleranceDegrees
            && abs(lhs.longitude - rhs.longitude) <= toleranceDegrees
    }
}

/// Validasi minimal plan sebelum commit: polygon minimal 3 titik, luas > 0, tidak self-intersect.
enum FieldPlanValidator {
    static func isValid(_ plan: MulchRowPlan) -> Bool {
        guard plan.boundary.points.count >= 3 else { return false }
        guard plan.boundary.areaSquareMeters > 0, plan.boundary.areaSquareMeters.isFinite else { return false }
        guard !FieldGeometryCalculator.hasSelfIntersection(plan.boundary.points) else { return false }
        return true
    }
}

/// Draft edit kebun (nama + plan) yang dikirim ke transaksi store.
struct FieldEditDraft: Equatable {
    var name: String
    var plan: MulchRowPlan
}
