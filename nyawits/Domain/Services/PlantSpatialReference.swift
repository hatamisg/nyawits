import CoreLocation
import MapKit

/// Fixed orientation: towards north, or east for an exactly horizontal row.
/// A is the left side of that orientation, B the right, independent of walking direction.
enum PlantSpatialReference {
    static func endpoints(_ row: MulchRow) -> (MKMapPoint, MKMapPoint) {
        let a = MKMapPoint(row.pointA), b = MKMapPoint(row.pointB)
        if b.y < a.y || (abs(b.y - a.y) < 0.000001 && b.x > a.x) { return (a, b) }
        return (b, a)
    }

    static func coordinate(row: MulchRow, progress: Double, side: PlantCaptureSide? = nil,
                           offsetMeters: Double = 0) -> CLLocationCoordinate2D {
        let (a, b) = endpoints(row)
        let dx = b.x - a.x, dy = b.y - a.y
        let length = max(hypot(dx, dy), 0.000001)
        let t = min(1, max(0, progress))
        let offset = offsetMeters / MKMetersPerMapPointAtLatitude(row.pointA.latitude)
        let sign = side == .left ? 1.0 : (side == .right ? -1.0 : 0)
        return MKMapPoint(x: a.x + dx * t + dy / length * offset * sign,
                          y: a.y + dy * t - dx / length * offset * sign).coordinate
    }

    static func sideLabel(row: MulchRow, side: PlantCaptureSide) -> String {
        let (a, b) = endpoints(row)
        let sign = side == .left ? 1.0 : -1.0
        let east = (b.y - a.y) * sign, north = (b.x - a.x) * sign
        let angle = (atan2(east, north) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        let names = ["utara", "timur laut", "timur", "tenggara", "selatan", "barat daya", "barat", "barat laut"]
        return "\(side.title): \(names[Int((angle + 22.5) / 45) % 8])"
    }

    static func canonicalProgress(row: MulchRow, coordinate: CLLocationCoordinate2D) -> Double {
        let (a, b) = endpoints(row), p = MKMapPoint(coordinate)
        let dx = b.x - a.x, dy = b.y - a.y
        return min(1, max(0, ((p.x - a.x) * dx + (p.y - a.y) * dy) / max(dx * dx + dy * dy, 0.000001)))
    }
}

/// AR's gravityAndHeading world has +x east and +z south. Only relative motion
/// within one continuous tracking segment is applied to a timestamped GPS anchor.
struct PlantPositionEstimator {
    struct Anchor {
        let location: CLLocation
        let transform: [Float]
        let frameTimestamp: TimeInterval
    }
    struct Estimate {
        let coordinate: CLLocationCoordinate2D
        let method: String
        let uncertainty: Double
        let anchor: Anchor?
    }
    private(set) var anchor: Anchor?
    mutating func reset() { anchor = nil }

    mutating func estimate(location: CLLocation?, transform: [Float], timestamp: TimeInterval,
                           trackingNormal: Bool, headingAccurate: Bool) -> Estimate? {
        if !trackingNormal || !headingAccurate { anchor = nil }
        if let current = anchor, timestamp < current.frameTimestamp || timestamp - current.frameTimestamp > 60 { anchor = nil }
        if trackingNormal, headingAccurate, transform.count == 16 {
            if anchor == nil, let location, location.horizontalAccuracy <= 10 {
                anchor = Anchor(location: location, transform: transform, frameTimestamp: timestamp)
            }
            if let anchor {
                let east = Double(transform[12] - anchor.transform[12])
                let south = Double(transform[14] - anchor.transform[14])
                let distance = hypot(east, south)
                if distance <= 30 {
                    let origin = MKMapPoint(anchor.location.coordinate)
                    let metersPerPoint = MKMetersPerMapPointAtLatitude(anchor.location.coordinate.latitude)
                    return Estimate(coordinate: MKMapPoint(x: origin.x + east / metersPerPoint,
                                                           y: origin.y + south / metersPerPoint).coordinate,
                                    method: "gpsAR", uncertainty: anchor.location.horizontalAccuracy + distance * 0.05,
                                    anchor: anchor)
                }
                self.anchor = nil
            }
        }
        guard let location else { return nil }
        return Estimate(coordinate: location.coordinate, method: "gps", uncertainty: location.horizontalAccuracy, anchor: nil)
    }
}
