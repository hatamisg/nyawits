import Combine
import CoreLocation
import Foundation

@MainActor
final class FieldAreaSelectionViewModel: ObservableObject {
    @Published private(set) var points: [BoundaryPoint] = []
    @Published var mapStyle: FieldMapStyle = .satellite
    @Published var recenterRequest: MapRecenterRequest?
    @Published private(set) var fitRequest: MapFitRequest?
    @Published var isHelpPresented = false
    @Published var isClearConfirmationPresented = false
    @Published var confirmedBoundary: FieldBoundary?
    @Published var notice: String?

    private let minimumPointDistanceMeters = 1.0
    private let maximumPointCount = 50

    /// Mode edit: boundary tersimpan menjadi titik awal dan peta memuatnya sekali.
    /// Mode create (default) tetap kosong tanpa fit request.
    init(initialBoundary: FieldBoundary? = nil) {
        guard let initialBoundary, !initialBoundary.points.isEmpty else { return }
        points = initialBoundary.points
        _fitRequest = Published(
            initialValue: MapFitRequest(points: initialBoundary.points.map { GeoCoordinate($0.coordinate) })
        )
    }

    var areaSquareMeters: Double {
        FieldGeometryCalculator.area(for: points)
    }

    var perimeterMeters: Double {
        FieldGeometryCalculator.perimeter(for: points)
    }

    var hasSelfIntersection: Bool {
        FieldGeometryCalculator.hasSelfIntersection(points)
    }

    var canConfirm: Bool {
        points.count >= 3 && areaSquareMeters > 0 && !hasSelfIntersection
    }

    var validationMessage: String? {
        guard points.count >= 3, hasSelfIntersection else { return nil }
        return "Boundary lines can’t cross. Drag a point to fix the shape."
    }

    func addPoint(at coordinate: CLLocationCoordinate2D) {
        guard points.count < maximumPointCount else {
            notice = "A boundary can contain up to \(maximumPointCount) points."
            return
        }

        guard points.allSatisfy({ FieldGeometryCalculator.distance(from: $0.coordinate, to: coordinate) >= minimumPointDistanceMeters }) else {
            notice = "Place the new point at least 1 metre from another point."
            return
        }

        points.append(BoundaryPoint(coordinate: coordinate))
        notice = nil
    }

    func movePoint(id: UUID, to coordinate: CLLocationCoordinate2D) {
        guard let index = points.firstIndex(where: { $0.id == id }) else { return }
        points[index].coordinate = coordinate
        notice = nil
    }

    func undo() {
        guard !points.isEmpty else { return }
        points.removeLast()
        notice = nil
    }

    func clear() {
        points.removeAll()
        notice = nil
    }

    func requestClear() {
        guard !points.isEmpty else { return }
        isClearConfirmationPresented = true
    }

    func recenter(on coordinate: CLLocationCoordinate2D) {
        recenterRequest = MapRecenterRequest(coordinate: coordinate)
    }

    func confirm() -> FieldBoundary? {
        guard canConfirm else { return nil }
        let boundary = FieldBoundary(
            points: points,
            areaSquareMeters: areaSquareMeters,
            perimeterMeters: perimeterMeters
        )
        confirmedBoundary = boundary
        return boundary
    }
}
