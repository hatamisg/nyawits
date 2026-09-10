import CoreLocation
import Foundation

struct FieldBoundary: Identifiable, Equatable {
    let id: UUID
    let points: [BoundaryPoint]
    let areaSquareMeters: Double
    let perimeterMeters: Double

    init(
        id: UUID = UUID(),
        points: [BoundaryPoint],
        areaSquareMeters: Double,
        perimeterMeters: Double
    ) {
        self.id = id
        self.points = points
        self.areaSquareMeters = areaSquareMeters
        self.perimeterMeters = perimeterMeters
    }
}

enum FieldMapStyle: String, CaseIterable, Identifiable {
    case standard
    case satellite
    case hybrid

    var id: Self { self }

    var title: String {
        switch self {
        case .standard: "Map"
        case .satellite: "Satellite"
        case .hybrid: "Hybrid"
        }
    }
}

struct MapRecenterRequest: Equatable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: MapRecenterRequest, rhs: MapRecenterRequest) -> Bool {
        lhs.id == rhs.id
    }
}
