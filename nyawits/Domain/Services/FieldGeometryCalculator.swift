import CoreLocation
import Foundation
import MapKit

enum FieldGeometryCalculator {
    private static let earthRadiusMeters = 6_378_137.0
    private static let intersectionTolerance = 0.000_001

    static func distance(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
    }

    static func segmentDistances(for points: [BoundaryPoint]) -> [Double] {
        guard points.count >= 2 else { return [] }

        var distances = zip(points, points.dropFirst()).map {
            distance(from: $0.coordinate, to: $1.coordinate)
        }

        if points.count >= 3, let first = points.first, let last = points.last {
            distances.append(distance(from: last.coordinate, to: first.coordinate))
        }

        return distances
    }

    static func perimeter(for points: [BoundaryPoint]) -> Double {
        segmentDistances(for: points).reduce(0, +)
    }

    static func area(for points: [BoundaryPoint]) -> Double {
        guard points.count >= 3 else { return 0 }

        var sphericalExcess = 0.0

        for index in points.indices {
            let current = points[index].coordinate
            let next = points[(index + 1) % points.count].coordinate
            let currentLatitude = current.latitude * .pi / 180
            let nextLatitude = next.latitude * .pi / 180
            let longitudeDelta = normalizedLongitudeDelta(next.longitude - current.longitude) * .pi / 180

            sphericalExcess += longitudeDelta * (2 + sin(currentLatitude) + sin(nextLatitude))
        }

        return abs(sphericalExcess) * earthRadiusMeters * earthRadiusMeters / 2
    }

    static func hasSelfIntersection(_ points: [BoundaryPoint]) -> Bool {
        guard points.count >= 4 else { return false }

        let mapPoints = points.map { MKMapPoint($0.coordinate) }
        let edgeCount = mapPoints.count

        for firstEdge in 0..<edgeCount {
            let firstStart = mapPoints[firstEdge]
            let firstEnd = mapPoints[(firstEdge + 1) % edgeCount]

            for secondEdge in (firstEdge + 1)..<edgeCount {
                if edgesAreAdjacent(firstEdge, secondEdge, edgeCount: edgeCount) {
                    continue
                }

                let secondStart = mapPoints[secondEdge]
                let secondEnd = mapPoints[(secondEdge + 1) % edgeCount]

                if segmentsIntersect(firstStart, firstEnd, secondStart, secondEnd) {
                    return true
                }
            }
        }

        return false
    }

    static func midpoint(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let startLatitude = start.latitude * .pi / 180
        let startLongitude = start.longitude * .pi / 180
        let endLatitude = end.latitude * .pi / 180
        let longitudeDelta = normalizedLongitudeDelta(end.longitude - start.longitude) * .pi / 180

        let x = cos(endLatitude) * cos(longitudeDelta)
        let y = cos(endLatitude) * sin(longitudeDelta)
        let latitude = atan2(
            sin(startLatitude) + sin(endLatitude),
            sqrt((cos(startLatitude) + x) * (cos(startLatitude) + x) + y * y)
        )
        let longitude = startLongitude + atan2(y, cos(startLatitude) + x)

        return CLLocationCoordinate2D(latitude: latitude * 180 / .pi, longitude: longitude * 180 / .pi)
    }

    private static func normalizedLongitudeDelta(_ degrees: Double) -> Double {
        var result = degrees
        while result > 180 { result -= 360 }
        while result < -180 { result += 360 }
        return result
    }

    private static func edgesAreAdjacent(_ first: Int, _ second: Int, edgeCount: Int) -> Bool {
        abs(first - second) == 1 || (first == 0 && second == edgeCount - 1)
    }

    private static func segmentsIntersect(
        _ firstStart: MKMapPoint,
        _ firstEnd: MKMapPoint,
        _ secondStart: MKMapPoint,
        _ secondEnd: MKMapPoint
    ) -> Bool {
        let o1 = orientation(firstStart, firstEnd, secondStart)
        let o2 = orientation(firstStart, firstEnd, secondEnd)
        let o3 = orientation(secondStart, secondEnd, firstStart)
        let o4 = orientation(secondStart, secondEnd, firstEnd)

        if differentSigns(o1, o2), differentSigns(o3, o4) {
            return true
        }

        if abs(o1) <= intersectionTolerance, point(secondStart, liesOnSegmentFrom: firstStart, to: firstEnd) { return true }
        if abs(o2) <= intersectionTolerance, point(secondEnd, liesOnSegmentFrom: firstStart, to: firstEnd) { return true }
        if abs(o3) <= intersectionTolerance, point(firstStart, liesOnSegmentFrom: secondStart, to: secondEnd) { return true }
        if abs(o4) <= intersectionTolerance, point(firstEnd, liesOnSegmentFrom: secondStart, to: secondEnd) { return true }

        return false
    }

    private static func orientation(_ first: MKMapPoint, _ second: MKMapPoint, _ third: MKMapPoint) -> Double {
        (second.x - first.x) * (third.y - first.y) - (second.y - first.y) * (third.x - first.x)
    }

    private static func differentSigns(_ first: Double, _ second: Double) -> Bool {
        (first > intersectionTolerance && second < -intersectionTolerance)
            || (first < -intersectionTolerance && second > intersectionTolerance)
    }

    private static func point(_ point: MKMapPoint, liesOnSegmentFrom start: MKMapPoint, to end: MKMapPoint) -> Bool {
        point.x >= min(start.x, end.x) - intersectionTolerance
            && point.x <= max(start.x, end.x) + intersectionTolerance
            && point.y >= min(start.y, end.y) - intersectionTolerance
            && point.y <= max(start.y, end.y) + intersectionTolerance
    }
}
