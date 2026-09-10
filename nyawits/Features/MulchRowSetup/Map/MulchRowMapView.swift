import MapKit
import SwiftUI

struct MulchRowMapView: UIViewRepresentable {
    let boundary: FieldBoundary
    let rows: [MulchRow]
    let rotationDegrees: Double
    let mapStyle: FieldMapStyle
    let userCoordinate: CLLocationCoordinate2D?
    let userHorizontalAccuracy: CLLocationAccuracy?
    let recenterRequest: MapRecenterRequest?
    let fitBoundaryRequestID: UUID
    let bottomContentInset: CGFloat
    let onRotationBegan: () -> Void
    let onRotationChanged: (Double) -> Void
    let onRotationEnded: () -> Void

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
        mapView.isRotateEnabled = false
        mapView.pointOfInterestFilter = .excludingAll

        let rotationRecognizer = UIRotationGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleRowRotation(_:))
        )
        rotationRecognizer.delegate = context.coordinator
        mapView.addGestureRecognizer(rotationRecognizer)
        context.coordinator.rotationRecognizer = rotationRecognizer

        context.coordinator.synchronizeMap(mapView, force: true)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        mapView.layoutMargins = UIEdgeInsets(top: 118, left: 12, bottom: bottomContentInset, right: 12)

        if mapView.mapType != mapStyle.mapType {
            mapView.mapType = mapStyle.mapType
        }

        context.coordinator.synchronizeMap(mapView)

        if let request = recenterRequest, request.id != context.coordinator.lastRecenterRequestID {
            context.coordinator.lastRecenterRequestID = request.id
            mapView.setRegion(
                MKCoordinateRegion(
                    center: request.coordinate,
                    latitudinalMeters: 500,
                    longitudinalMeters: 500
                ),
                animated: true
            )
        }

        if context.coordinator.lastFitBoundaryRequestID == nil {
            context.coordinator.lastFitBoundaryRequestID = fitBoundaryRequestID
            DispatchQueue.main.async { [weak mapView, weak coordinator = context.coordinator] in
                guard let mapView, let coordinator else { return }
                coordinator.fitBoundary(in: mapView, animated: false)
            }
        } else if fitBoundaryRequestID != context.coordinator.lastFitBoundaryRequestID {
            context.coordinator.lastFitBoundaryRequestID = fitBoundaryRequestID
            context.coordinator.fitBoundary(in: mapView, animated: true)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: MulchRowMapView
        weak var rotationRecognizer: UIRotationGestureRecognizer?
        var lastRecenterRequestID: UUID?
        var lastFitBoundaryRequestID: UUID?

        private var initialRotationDegrees = 0.0
        private var renderedRows: [MulchRow] = []
        private var renderedUserCoordinate: CLLocationCoordinate2D?
        private var renderedAccuracy: CLLocationAccuracy?
        private var boundaryOverlayID: ObjectIdentifier?
        private var accuracyOverlayID: ObjectIdentifier?
        private var rowOverlayIDs: Set<ObjectIdentifier> = []

        init(parent: MulchRowMapView) {
            self.parent = parent
        }

        @objc func handleRowRotation(_ recognizer: UIRotationGestureRecognizer) {
            switch recognizer.state {
            case .began:
                initialRotationDegrees = parent.rotationDegrees
                parent.onRotationBegan()
            case .changed:
                let delta = recognizer.rotation * 180 / .pi
                parent.onRotationChanged(initialRotationDegrees + delta)
            case .ended:
                let delta = recognizer.rotation * 180 / .pi
                parent.onRotationChanged(initialRotationDegrees + delta)
                parent.onRotationEnded()
            case .cancelled, .failed:
                parent.onRotationEnded()
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            gestureRecognizer === rotationRecognizer || otherGestureRecognizer === rotationRecognizer
        }

        func synchronizeMap(_ mapView: MKMapView, force: Bool = false) {
            let userChanged = !coordinatesEqual(renderedUserCoordinate, parent.userCoordinate)
            let accuracyChanged = renderedAccuracy != parent.userHorizontalAccuracy
            guard force || renderedRows != parent.rows || userChanged || accuracyChanged else { return }

            renderedRows = parent.rows
            renderedUserCoordinate = parent.userCoordinate
            renderedAccuracy = parent.userHorizontalAccuracy

            mapView.removeAnnotations(mapView.annotations.filter { $0 is MulchDeviceLocationAnnotation })
            mapView.removeOverlays(mapView.overlays)
            boundaryOverlayID = nil
            accuracyOverlayID = nil
            rowOverlayIDs.removeAll()

            addBoundary(to: mapView)
            addRows(to: mapView)
            addLocation(to: mapView)
        }

        func fitBoundary(in mapView: MKMapView, animated: Bool) {
            let coordinates = parent.boundary.points.map(\.coordinate)
            guard coordinates.count >= 3 else { return }
            let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
            let boundaryRegion = MKCoordinateRegion(polygon.boundingMapRect)
            let latitudeDelta = max(boundaryRegion.span.latitudeDelta * 1.75, 0.000_05)
            let longitudeDelta = max(boundaryRegion.span.longitudeDelta * 1.55, 0.000_05)
            let visibleCenter = CLLocationCoordinate2D(
                latitude: boundaryRegion.center.latitude - latitudeDelta * 0.13,
                longitude: boundaryRegion.center.longitude
            )
            mapView.setRegion(
                MKCoordinateRegion(
                    center: visibleCenter,
                    span: MKCoordinateSpan(
                        latitudeDelta: latitudeDelta,
                        longitudeDelta: longitudeDelta
                    )
                ),
                animated: animated
            )
        }

        private func addBoundary(to mapView: MKMapView) {
            let coordinates = parent.boundary.points.map(\.coordinate)
            guard coordinates.count >= 3 else { return }
            let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
            boundaryOverlayID = ObjectIdentifier(polygon)
            mapView.addOverlay(polygon)
        }

        private func addRows(to mapView: MKMapView) {
            for row in parent.rows {
                let coordinates = [row.pointA, row.pointB]
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                rowOverlayIDs.insert(ObjectIdentifier(polyline))
                mapView.addOverlay(polyline, level: .aboveLabels)
            }
        }

        private func addLocation(to mapView: MKMapView) {
            guard let coordinate = parent.userCoordinate else { return }

            if let accuracy = parent.userHorizontalAccuracy, accuracy > 0 {
                let circle = MKCircle(center: coordinate, radius: accuracy)
                accuracyOverlayID = ObjectIdentifier(circle)
                mapView.addOverlay(circle, level: .aboveLabels)
            }
            mapView.addAnnotation(MulchDeviceLocationAnnotation(coordinate: coordinate))
        }

        private func coordinatesEqual(_ lhs: CLLocationCoordinate2D?, _ rhs: CLLocationCoordinate2D?) -> Bool {
            switch (lhs, rhs) {
            case (.none, .none): true
            case let (.some(lhs), .some(rhs)):
                lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
            default: false
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let location = annotation as? MulchDeviceLocationAnnotation else { return nil }
            let identifier = "MulchDeviceLocation"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: location, reuseIdentifier: identifier)
            view.annotation = location
            view.markerTintColor = UIColor(red: 0.45, green: 0.91, blue: 0.13, alpha: 1)
            view.glyphText = "H"
            view.glyphTintColor = UIColor(red: 0.08, green: 0.20, blue: 0.05, alpha: 1)
            view.canShowCallout = false
            view.displayPriority = .required
            view.accessibilityLabel = "Current location"
            return view
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let identifier = ObjectIdentifier(overlay as AnyObject)

            if identifier == boundaryOverlayID, let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.strokeColor = UIColor.white.withAlphaComponent(0.95)
                renderer.fillColor = UIColor(red: 0.04, green: 0.50, blue: 0.34, alpha: 0.16)
                renderer.lineWidth = 3
                renderer.lineJoin = .round
                return renderer
            }

            if identifier == accuracyOverlayID, let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.75)
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.12)
                renderer.lineWidth = 1.5
                return renderer
            }

            if rowOverlayIDs.contains(identifier), let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 0.03, green: 0.86, blue: 0.98, alpha: 1)
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

private final class MulchDeviceLocationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}
