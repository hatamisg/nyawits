import CoreLocation
import Foundation

struct MulchRow: Identifiable, Equatable {
    let id: UUID
    var pointA: CLLocationCoordinate2D
    var pointB: CLLocationCoordinate2D

    init(
        id: UUID = UUID(),
        pointA: CLLocationCoordinate2D,
        pointB: CLLocationCoordinate2D
    ) {
        self.id = id
        self.pointA = pointA
        self.pointB = pointB
    }

    static func == (lhs: MulchRow, rhs: MulchRow) -> Bool {
        lhs.id == rhs.id
            && coordinatesEqual(lhs.pointA, rhs.pointA)
            && coordinatesEqual(lhs.pointB, rhs.pointB)
    }

    private static func coordinatesEqual(
        _ lhs: CLLocationCoordinate2D,
        _ rhs: CLLocationCoordinate2D
    ) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct MulchRowPlan: Equatable {
    let boundary: FieldBoundary
    let rows: [MulchRow]
    let rotationDegrees: Double

    init(boundary: FieldBoundary, rows: [MulchRow], rotationDegrees: Double = 0) {
        self.boundary = boundary
        self.rows = rows
        self.rotationDegrees = rotationDegrees
    }
}

enum MulchRowEndpoint: Equatable {
    case pointA
    case pointB
}

struct MulchRowProjection: Equatable {
    let rowID: UUID
    let coordinate: CLLocationCoordinate2D
    let distanceMeters: Double
    let normalizedPosition: Double

    static func == (lhs: MulchRowProjection, rhs: MulchRowProjection) -> Bool {
        lhs.rowID == rhs.rowID
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.distanceMeters == rhs.distanceMeters
            && lhs.normalizedPosition == rhs.normalizedPosition
    }
}
