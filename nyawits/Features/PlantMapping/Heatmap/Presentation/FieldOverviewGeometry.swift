import CoreGraphics
import MapKit

struct FieldOverviewGeometry {
    private let mapRect: MKMapRect
    private let drawingRect: CGRect
    private let scale: CGFloat

    init(field: MappedField, size: CGSize, padding: CGFloat = 24) {
        let polygon = MKPolygon(
            coordinates: field.boundaryPoints.map(\.coordinate),
            count: field.boundaryPoints.count
        )
        mapRect = polygon.boundingMapRect

        let available = CGSize(
            width: max(1, size.width - padding * 2),
            height: max(1, size.height - padding * 2)
        )
        let horizontalScale = available.width / max(1, mapRect.size.width)
        let verticalScale = available.height / max(1, mapRect.size.height)
        scale = min(horizontalScale, verticalScale)

        let contentSize = CGSize(
            width: mapRect.size.width * scale,
            height: mapRect.size.height * scale
        )
        drawingRect = CGRect(
            x: (size.width - contentSize.width) / 2,
            y: (size.height - contentSize.height) / 2,
            width: contentSize.width,
            height: contentSize.height
        )
    }

    func point(for coordinate: CLLocationCoordinate2D) -> CGPoint {
        let point = MKMapPoint(coordinate)
        return CGPoint(
            x: drawingRect.minX + (point.x - mapRect.minX) * scale,
            y: drawingRect.minY + (point.y - mapRect.minY) * scale
        )
    }
}
