import MapKit
import SwiftUI

/// Permintaan sekali-pakai agar kamera memuat seluruh titik (mode edit boundary).
struct MapFitRequest: Equatable {
    let id = UUID()
    let points: [GeoCoordinate]
}

struct FieldMapView: UIViewRepresentable {
    let points: [BoundaryPoint]
    let mapStyle: FieldMapStyle
    let userCoordinate: CLLocationCoordinate2D?
    let recenterRequest: MapRecenterRequest?
    var fitRequest: MapFitRequest? = nil
    let bottomContentInset: CGFloat
    let onMapTap: (CLLocationCoordinate2D) -> Void
    let onPointMoved: (UUID, CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.mapType = mapStyle.mapType
        mapView.showsCompass = false
        mapView.showsScale = true
        mapView.isPitchEnabled = false
        mapView.pointOfInterestFilter = .excludingAll

        let jakarta = CLLocationCoordinate2D(latitude: -6.200_000, longitude: 106.816_666)
        mapView.setRegion(
            MKCoordinateRegion(
                center: jakarta,
                latitudinalMeters: 250,
                longitudinalMeters: 250
            ),
            animated: false
        )

        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        tapRecognizer.delegate = context.coordinator
        tapRecognizer.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tapRecognizer)

        context.coordinator.synchronizeMap(mapView, force: true)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        mapView.layoutMargins = UIEdgeInsets(top: 118, left: 12, bottom: bottomContentInset - 50, right: 12)

        if mapView.mapType != mapStyle.mapType {
            mapView.mapType = mapStyle.mapType
        }

        context.coordinator.synchronizeMap(mapView)

        if let request = recenterRequest, request.id != context.coordinator.lastRecenterRequestID {
            context.coordinator.lastRecenterRequestID = request.id
            mapView.setRegion(
                MKCoordinateRegion(
                    center: request.coordinate,
                    latitudinalMeters: 100,
                    longitudinalMeters: 100
                ),
                animated: true
            )
        }

        if let fitRequest, fitRequest.id != context.coordinator.lastFitRequestID {
            context.coordinator.lastFitRequestID = fitRequest.id
            let coordinates = fitRequest.points.map(\.coordinate)
            if !coordinates.isEmpty {
                // Muat seluruh boundary tersimpan tanpa mengikuti lokasi pengguna.
                mapView.setVisibleMapRect(
                    MKMapRect(fitting: coordinates),
                    edgePadding: UIEdgeInsets(top: 120, left: 60, bottom: bottomContentInset + 60, right: 60),
                    animated: false
                )
            }
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: FieldMapView
        var lastRecenterRequestID: UUID?
        var lastFitRequestID: UUID?

        private var renderedPoints: [BoundaryPoint] = []
        private var renderedUserCoordinate: CLLocationCoordinate2D?

        init(parent: FieldMapView) {
            self.parent = parent
        }

        @objc func handleMapTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let mapView = recognizer.view as? MKMapView else { return }
            let coordinate = mapView.convert(recognizer.location(in: mapView), toCoordinateFrom: mapView)
            parent.onMapTap(coordinate)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let mapView = gestureRecognizer.view as? MKMapView else { return false }

            var touchedView: UIView? = touch.view
            while let view = touchedView {
                if view is MKAnnotationView || view is UIControl { return false }
                touchedView = view.superview
            }

            if let view = touch.view, !view.isDescendant(of: mapView) {
                return false
            }

            let location = touch.location(in: mapView)
            let bounds = mapView.bounds

            // Abaikan tap di area top bar (back button & header)
            if location.y <= 120 {
                return false
            }

            // Abaikan tap di area bottom panel
            if location.y >= bounds.height - parent.bottomContentInset {
                return false
            }

            // Abaikan tap di area control cluster sisi kanan (button ?, layers, locate)
            let clusterWidth: CGFloat = 88
            let clusterBottom = bounds.height - (parent.bottomContentInset - 50)
            let clusterTop = clusterBottom - 210
            if location.x >= bounds.width - clusterWidth && location.y >= clusterTop && location.y <= clusterBottom {
                return false
            }

            return true
        }

        func synchronizeMap(_ mapView: MKMapView, force: Bool = false) {
            let userLocationChanged = !coordinatesAreEqual(renderedUserCoordinate, parent.userCoordinate)
            guard force || renderedPoints != parent.points || userLocationChanged else { return }

            renderedPoints = parent.points
            renderedUserCoordinate = parent.userCoordinate

            let managedAnnotations = mapView.annotations.filter {
                $0 is BoundaryPointAnnotation || $0 is DistanceLabelAnnotation || $0 is DeviceLocationAnnotation
            }
            mapView.removeAnnotations(managedAnnotations)
            mapView.removeOverlays(mapView.overlays)

            let pointAnnotations = parent.points.enumerated().map { index, point in
                BoundaryPointAnnotation(point: point, number: index + 1)
            }
            mapView.addAnnotations(pointAnnotations)

            if let userCoordinate = parent.userCoordinate {
                mapView.addAnnotation(DeviceLocationAnnotation(coordinate: userCoordinate))
            }

            addBoundaryOverlay(to: mapView)
            addDistanceLabels(to: mapView)
        }

        private func addBoundaryOverlay(to mapView: MKMapView) {
            let coordinates = parent.points.map(\.coordinate)

            if coordinates.count == 2 {
                mapView.addOverlay(MKPolyline(coordinates: coordinates, count: coordinates.count))
            } else if coordinates.count >= 3 {
                mapView.addOverlay(MKPolygon(coordinates: coordinates, count: coordinates.count))
            }
        }

        private func addDistanceLabels(to mapView: MKMapView) {
            guard parent.points.count >= 2 else { return }

            var pointPairs = Array(zip(parent.points, parent.points.dropFirst()))
            if parent.points.count >= 3, let first = parent.points.first, let last = parent.points.last {
                pointPairs.append((last, first))
            }

            let annotations = pointPairs.map { start, end in
                let distance = FieldGeometryCalculator.distance(from: start.coordinate, to: end.coordinate)
                return DistanceLabelAnnotation(
                    coordinate: FieldGeometryCalculator.midpoint(from: start.coordinate, to: end.coordinate),
                    text: FieldMeasurementFormatter.distance(distance)
                )
            }
            mapView.addAnnotations(annotations)
        }

        private func coordinatesAreEqual(
            _ first: CLLocationCoordinate2D?,
            _ second: CLLocationCoordinate2D?
        ) -> Bool {
            switch (first, second) {
            case (.none, .none):
                true
            case let (.some(first), .some(second)):
                first.latitude == second.latitude && first.longitude == second.longitude
            default:
                false
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            switch annotation {
            case let pointAnnotation as BoundaryPointAnnotation:
                let identifier = "BoundaryPoint"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                    ?? MKMarkerAnnotationView(annotation: pointAnnotation, reuseIdentifier: identifier)
                view.annotation = pointAnnotation
                view.markerTintColor = UIColor(red: 0.38, green: 0.08, blue: 0.82, alpha: 1)
                view.glyphText = String(pointAnnotation.number)
                view.glyphTintColor = .white
                view.titleVisibility = .hidden
                view.subtitleVisibility = .hidden
                view.canShowCallout = false
                view.isDraggable = true
                view.displayPriority = .required
                view.accessibilityLabel = "Boundary point \(pointAnnotation.number)"
                view.accessibilityHint = "Drag to adjust this point"
                return view

            case let labelAnnotation as DistanceLabelAnnotation:
                let identifier = "DistanceLabel"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? DistanceAnnotationView)
                    ?? DistanceAnnotationView(annotation: labelAnnotation, reuseIdentifier: identifier)
                view.annotation = labelAnnotation
                view.configure(text: labelAnnotation.text)
                return view

            case let locationAnnotation as DeviceLocationAnnotation:
                let identifier = "DeviceLocation"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                    ?? MKMarkerAnnotationView(annotation: locationAnnotation, reuseIdentifier: identifier)
                view.annotation = locationAnnotation
                view.markerTintColor = UIColor(red: 0.45, green: 0.91, blue: 0.13, alpha: 1)
                view.glyphText = "H"
                view.glyphTintColor = UIColor(red: 0.08, green: 0.20, blue: 0.05, alpha: 1)
                view.canShowCallout = false
                view.isDraggable = false
                view.displayPriority = .required
                view.accessibilityLabel = "Current location"
                return view

            default:
                return nil
            }
        }

        func mapView(
            _ mapView: MKMapView,
            annotationView view: MKAnnotationView,
            didChange newState: MKAnnotationView.DragState,
            fromOldState oldState: MKAnnotationView.DragState
        ) {
            guard let annotation = view.annotation as? BoundaryPointAnnotation else { return }

            if newState == .ending || newState == .canceling {
                parent.onPointMoved(annotation.pointID, annotation.coordinate)
                view.setDragState(.none, animated: true)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let lineColor = FieldGeometryCalculator.hasSelfIntersection(parent.points)
                ? UIColor.systemRed
                : UIColor(red: 0.03, green: 0.88, blue: 0.92, alpha: 1)

            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.strokeColor = lineColor
                renderer.fillColor = UIColor(red: 0.04, green: 0.50, blue: 0.34, alpha: 0.30)
                renderer.lineWidth = 4
                renderer.lineJoin = .round
                return renderer
            }

            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = lineColor
                renderer.lineWidth = 4
                renderer.lineJoin = .round
                renderer.lineCap = .round
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

private final class BoundaryPointAnnotation: NSObject, MKAnnotation {
    let pointID: UUID
    let number: Int
    @objc dynamic var coordinate: CLLocationCoordinate2D

    init(point: BoundaryPoint, number: Int) {
        pointID = point.id
        self.number = number
        coordinate = point.coordinate
    }
}

private final class DistanceLabelAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let text: String

    init(coordinate: CLLocationCoordinate2D, text: String) {
        self.coordinate = coordinate
        self.text = text
    }
}

private final class DeviceLocationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

private final class DistanceAnnotationView: MKAnnotationView {
    private let label = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        label.backgroundColor = UIColor.black.withAlphaComponent(0.88)
        label.textColor = .white
        let preferredSize = UIFont.preferredFont(forTextStyle: .caption1).pointSize
        label.font = .systemFont(ofSize: preferredSize, weight: .bold)
        label.textAlignment = .center
        label.layer.cornerRadius = 5
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        collisionMode = .rectangle
        displayPriority = .defaultHigh
        isEnabled = false
        accessibilityTraits = .staticText
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(text: String) {
        label.text = "  \(text)  "
        label.sizeToFit()
        bounds.size = CGSize(width: max(52, label.bounds.width), height: 26)
        accessibilityLabel = "Segment length \(text)"
    }
}

extension FieldMapStyle {
    var mapType: MKMapType {
        switch self {
        case .standard: .standard
        case .satellite: .satellite
        case .hybrid: .hybrid
        }
    }
}

private extension MKMapRect {
    /// Rect terkecil yang memuat seluruh koordinat.
    init(fitting coordinates: [CLLocationCoordinate2D]) {
        var rect = MKMapRect.null
        for coordinate in coordinates {
            let point = MKMapPoint(coordinate)
            let pointRect = MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0))
            rect = rect.isNull ? pointRect : rect.union(pointRect)
        }
        self = rect
    }
}

#if DEBUG
#Preview {
    FieldMapView(points: PreviewFixtures.boundary.points, mapStyle: .satellite, userCoordinate: nil, recenterRequest: nil, fitRequest: MapFitRequest(points: PreviewFixtures.field.boundaryPoints), bottomContentInset: 0, onMapTap: { _ in }, onPointMoved: { _, _ in })
}
#endif
