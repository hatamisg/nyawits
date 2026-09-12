import CoreLocation
import Foundation
import MapKit

/// Contoh sebaran spasial sintetik untuk pratinjau tampilan.
///
/// BUKAN hasil pengukuran dan bukan model diagnosis cabai. Angkanya dibangkitkan
/// generator acak berbenih tetap, lalu ditandai `ndreSource = "simulated"` dan
/// `isDemo = true` supaya UI selalu bisa menyebutnya simulasi.
///
/// Ini satu-satunya penulis kolom lama `ndre` yang tersisa; pengukuran
/// sungguhan hidup di `ScanSession`, bukan di `PlantObservation`.
enum VigorDemoFactory {
    static func makeField() -> MappedField {
        let origin = MKMapPoint(CLLocationCoordinate2D(latitude: -6.901, longitude: 107.600))
        let metersPerPoint = MKMetersPerMapPointAtLatitude(-6.901)
        func coordinate(_ east: Double, _ north: Double) -> CLLocationCoordinate2D {
            // Slight rotation gives the demo the same geographic geometry as real fields.
            let angle = 12.0 * Double.pi / 180
            let x = east * cos(angle) + north * sin(angle)
            let y = -east * sin(angle) + north * cos(angle)
            return MKMapPoint(x: origin.x + x / metersPerPoint, y: origin.y - y / metersPerPoint).coordinate
        }
        let points = [coordinate(0, 0), coordinate(20, 0), coordinate(20, 19), coordinate(0, 19)]
            .map { BoundaryPoint(coordinate: $0) }
        let boundary = FieldBoundary(points: points, areaSquareMeters: FieldGeometryCalculator.area(for: points),
                                     perimeterMeters: FieldGeometryCalculator.perimeter(for: points))
        let rows = (0..<10).map { i in
            MulchRow(id: identifier(100 + i), pointA: coordinate(Double(i) * 1.9 + 1.45, 1),
                     pointB: coordinate(Double(i) * 1.9 + 1.45, 18))
        }
        let fieldID = identifier(1), sessionID = identifier(2)
        var random = SeededRandom(state: 20260906)
        var observations: [PlantObservation] = []
        let date = Date(timeIntervalSince1970: 1788652800)
        for (rowIndex, row) in rows.enumerated() {
            for side in PlantCaptureSide.allCases {
                for sequence in 1...10 {
                    let t = Double(sequence) / 11
                    let position = PlantSpatialReference.coordinate(row: row, progress: t, side: side, offsetMeters: 0.34)
                    let x = Double(rowIndex) / 9
                    let patch = exp(-pow((x - 0.30) / 0.26, 2) - pow((t - 0.65) / 0.23, 2))
                    let variation = (random.next() - 0.5) * 0.18
                    let value = min(0.78, max(0.18, 0.60 + 0.12 * x - 0.40 * patch + variation))
                    var observation = PlantObservation(
                        id: identifier(1000 + observations.count), fieldID: fieldID, rowID: row.id,
                        rowNumber: rowIndex + 1, plantSequence: sequence, side: side, status: .captured,
                        capturedAt: date.addingTimeInterval(Double(observations.count) * 8), arFrameTimestamp: nil,
                        imageFilename: nil, location: GeoCoordinate(position), locationTimestamp: nil,
                        horizontalAccuracyMeters: nil, headingDegrees: nil, headingAccuracyDegrees: nil,
                        projectedCoordinate: GeoCoordinate(position), rowProgress: t, distanceFromRowMeters: 0.34,
                        cameraTransform: [], cameraIntrinsics: [], trackingQuality: .unavailable, motionWasStable: false)
                    observation.captureSessionID = sessionID
                    observation.positionMethod = "demo"
                    observation.sideReferenceVersion = 1
                    observation.ndre = (value * 1000).rounded() / 1000
                    observation.ndreSource = "simulated"
                    observations.append(observation)
                }
            }
        }
        var field = MappedField(id: fieldID, name: "Kebun Cabai • Demo", plan: MulchRowPlan(boundary: boundary, rows: rows, rotationDegrees: 12),
                                observations: observations, createdAt: date, updatedAt: date)
        field.isDemo = true
        field.completedRowSides = rows.flatMap { row in
            PlantCaptureSide.allCases.map { MappedField.completionKey(rowID: row.id, side: $0) }
        }
        return field
    }

    private static func identifier(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "D3E00000-0000-4000-8000-%012d", value))!
    }

    private struct SeededRandom {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(UInt64.max >> 11)
        }
    }
}
