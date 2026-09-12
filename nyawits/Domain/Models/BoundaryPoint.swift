import CoreLocation
import Foundation

struct BoundaryPoint: Identifiable, Equatable {
    let id: UUID
    var coordinate: CLLocationCoordinate2D

    init(id: UUID = UUID(), coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.coordinate = coordinate
    }

    static func == (lhs: BoundaryPoint, rhs: BoundaryPoint) -> Bool {
        lhs.id == rhs.id
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}
