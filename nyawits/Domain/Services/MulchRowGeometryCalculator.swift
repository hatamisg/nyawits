import CoreLocation
import Foundation
import MapKit

enum MulchRowGeometryCalculator {
    private static let minimumRowLengthMeters = 2.0
    private static let boundaryToleranceMeters = 0.35
    private static let intersectionTolerance = 0.000_001

    static func length(of row: MulchRow) -> Double {
        CLLocation(latitude: row.pointA.latitude, longitude: row.pointA.longitude)
            .distance(from: CLLocation(latitude: row.pointB.latitude, longitude: row.pointB.longitude))
    }

    static func contains(_ coordinate: CLLocationCoordinate2D, in boundary: FieldBoundary) -> Bool {
        let polygon = boundary.points.map { MKMapPoint($0.coordinate) }
        guard polygon.count >= 3 else { return false }

        let point = MKMapPoint(coordinate)
        if pointIsOnBoundary(point, polygon: polygon, latitude: coordinate.latitude) {
            return true
        }

        var isInside = false
        var previousIndex = polygon.count - 1

        for currentIndex in polygon.indices {
            let current = polygon[currentIndex]
            let previous = polygon[previousIndex]
            let crossesRay = (current.y > point.y) != (previous.y > point.y)

            if crossesRay {
                let intersectionX = (previous.x - current.x) * (point.y - current.y)
                    / (previous.y - current.y) + current.x
                if point.x < intersectionX {
                    isInside.toggle()
                }
            }
            previousIndex = currentIndex
        }

        return isInside
    }

    static func isValid(_ row: MulchRow, inside boundary: FieldBoundary, otherRows: [MulchRow]) -> Bool {
        guard length(of: row) >= minimumRowLengthMeters else { return false }
        guard rowIsInsideBoundary(row, boundary: boundary) else { return false }

        return otherRows.allSatisfy { other in
            other.id == row.id || !segmentsIntersect(row, other)
        }
    }

    static func nearestRow(to coordinate: CLLocationCoordinate2D, rows: [MulchRow]) -> MulchRowProjection? {
        let point = MKMapPoint(coordinate)

        return rows.compactMap { row -> MulchRowProjection? in
            let pointA = MKMapPoint(row.pointA)
            let pointB = MKMapPoint(row.pointB)
            let vectorX = pointB.x - pointA.x
            let vectorY = pointB.y - pointA.y
            let squaredLength = vectorX * vectorX + vectorY * vectorY
            guard squaredLength > 0 else { return nil }

            let rawPosition = ((point.x - pointA.x) * vectorX + (point.y - pointA.y) * vectorY) / squaredLength
            let position = min(1, max(0, rawPosition))
            let projected = MKMapPoint(
                x: pointA.x + position * vectorX,
                y: pointA.y + position * vectorY
            )

            return MulchRowProjection(
                rowID: row.id,
                coordinate: projected.coordinate,
                distanceMeters: point.distance(to: projected),
                normalizedPosition: position
            )
        }
        .min(by: { $0.distanceMeters < $1.distanceMeters })
    }

    static func generatedRows(
        count: Int,
        rotationDegrees: Double,
        inside boundary: FieldBoundary
    ) -> [MulchRow] {
        let polygon = boundary.points.map { MKMapPoint($0.coordinate) }
        guard polygon.count >= 3, count > 0 else { return [] }

        let normalizedDegrees = rotationDegrees.truncatingRemainder(dividingBy: 180)
        let radians = normalizedDegrees * .pi / 180
        let directionX = sin(radians)
        let directionY = -cos(radians)
        let normalX = -directionY
        let normalY = directionX
        let boundingRect = MKPolygon(
            coordinates: boundary.points.map(\.coordinate),
            count: boundary.points.count
        ).boundingMapRect
        let origin = MKMapPoint(x: boundingRect.midX, y: boundingRect.midY)

        let offsets = polygon.map { point in
            (point.x - origin.x) * normalX + (point.y - origin.y) * normalY
        }
        guard let minimumOffset = offsets.min(),
              let maximumOffset = offsets.max(),
              maximumOffset > minimumOffset else { return [] }

        let spacing = (maximumOffset - minimumOffset) / Double(count + 1)
        let averageLatitude = boundary.points.map(\.coordinate.latitude).reduce(0, +)
            / Double(boundary.points.count)
        let edgeInset = 0.35 / MKMetersPerMapPointAtLatitude(averageLatitude)

        return (1...count).compactMap { index in
            let offset = minimumOffset + Double(index) * spacing
            let lineOrigin = MKMapPoint(
                x: origin.x + normalX * offset,
                y: origin.y + normalY * offset
            )
            let intersections = lineIntersections(
                origin: lineOrigin,
                directionX: directionX,
                directionY: directionY,
                polygon: polygon
            )

            let segments = stride(from: 0, to: intersections.count - 1, by: 2).compactMap { segmentIndex -> (Double, Double)? in
                guard segmentIndex + 1 < intersections.count else { return nil }
                let first = intersections[segmentIndex]
                let second = intersections[segmentIndex + 1]
                return second > first ? (first, second) : nil
            }
            guard let longest = segments.max(by: { ($0.1 - $0.0) < ($1.1 - $1.0) }) else {
                return nil
            }

            let availableLength = longest.1 - longest.0
            let inset = min(edgeInset, availableLength * 0.08)
            guard availableLength > inset * 2 else { return nil }

            return MulchRow(
                pointA: MKMapPoint(
                    x: lineOrigin.x + directionX * (longest.0 + inset),
                    y: lineOrigin.y + directionY * (longest.0 + inset)
                ).coordinate,
                pointB: MKMapPoint(
                    x: lineOrigin.x + directionX * (longest.1 - inset),
                    y: lineOrigin.y + directionY * (longest.1 - inset)
                ).coordinate
            )
        }
    }

    static func rotationDegrees(of row: MulchRow) -> Double {
        let pointA = MKMapPoint(row.pointA)
        let pointB = MKMapPoint(row.pointB)
        let degrees = atan2(pointB.x - pointA.x, -(pointB.y - pointA.y)) * 180 / .pi
        return normalizedRotation(degrees)
    }

    static func generatedRows(
        from reference: MulchRow,
        inside boundary: FieldBoundary,
        spacingMeters: Double,
        maximumRows: Int = 200
    ) -> [MulchRow] {
        let polygon = boundary.points.map { MKMapPoint($0.coordinate) }
        guard polygon.count >= 3, spacingMeters > 0 else { return [] }

        var pointA = MKMapPoint(reference.pointA)
        var pointB = MKMapPoint(reference.pointB)
        var directionX = pointB.x - pointA.x
        var directionY = pointB.y - pointA.y
        let originalLength = hypot(directionX, directionY)
        guard originalLength > 0 else { return [] }

        directionX /= originalLength
        directionY /= originalLength

        if directionX < 0 || (abs(directionX) < intersectionTolerance && directionY < 0) {
            swap(&pointA, &pointB)
            directionX *= -1
            directionY *= -1
        }

        let normalX = -directionY
        let normalY = directionX
        let origin = MKMapPoint(x: (pointA.x + pointB.x) / 2, y: (pointA.y + pointB.y) / 2)
        let averageLatitude = boundary.points.map(\.coordinate.latitude).reduce(0, +)
            / Double(boundary.points.count)
        let metersPerMapPoint = MKMetersPerMapPointAtLatitude(averageLatitude)
        let spacing = spacingMeters / metersPerMapPoint
        let edgeInset = 0.55 / metersPerMapPoint

        let normalOffsets = polygon.map { point in
            (point.x - origin.x) * normalX + (point.y - origin.y) * normalY
        }
        guard let minimumOffset = normalOffsets.min(), let maximumOffset = normalOffsets.max() else { return [] }

        let firstStep = Int(ceil(minimumOffset / spacing))
        let lastStep = Int(floor(maximumOffset / spacing))
        guard firstStep <= lastStep else { return [] }

        var generated: [(offset: Double, row: MulchRow)] = []

        for step in firstStep...lastStep {
            let offset = Double(step) * spacing
            let lineOrigin = MKMapPoint(
                x: origin.x + normalX * offset,
                y: origin.y + normalY * offset
            )
            let intersections = lineIntersections(
                origin: lineOrigin,
                directionX: directionX,
                directionY: directionY,
                polygon: polygon
            )

            guard intersections.count >= 2 else { continue }

            var index = 0
            while index + 1 < intersections.count, generated.count < maximumRows {
                let startDistance = intersections[index] + edgeInset
                let endDistance = intersections[index + 1] - edgeInset
                index += 2

                guard endDistance > startDistance else { continue }

                let row = MulchRow(
                    pointA: MKMapPoint(
                        x: lineOrigin.x + directionX * startDistance,
                        y: lineOrigin.y + directionY * startDistance
                    ).coordinate,
                    pointB: MKMapPoint(
                        x: lineOrigin.x + directionX * endDistance,
                        y: lineOrigin.y + directionY * endDistance
                    ).coordinate
                )

                if length(of: row) >= minimumRowLengthMeters,
                   rowIsInsideBoundary(row, boundary: boundary) {
                    generated.append((offset, row))
                }
            }
        }

        return generated
            .sorted(by: { $0.offset < $1.offset })
            .map(\.row)
    }

    static func translated(
        _ row: MulchRow,
        from originalCoordinate: CLLocationCoordinate2D,
        to newCoordinate: CLLocationCoordinate2D
    ) -> MulchRow {
        let original = MKMapPoint(originalCoordinate)
        let updated = MKMapPoint(newCoordinate)
        let deltaX = updated.x - original.x
        let deltaY = updated.y - original.y

        return MulchRow(
            id: row.id,
            pointA: MKMapPoint(x: MKMapPoint(row.pointA).x + deltaX, y: MKMapPoint(row.pointA).y + deltaY).coordinate,
            pointB: MKMapPoint(x: MKMapPoint(row.pointB).x + deltaX, y: MKMapPoint(row.pointB).y + deltaY).coordinate
        )
    }

    static func normalizedRotation(_ degrees: Double) -> Double {
        let normalized = degrees.truncatingRemainder(dividingBy: 180)
        return normalized >= 0 ? normalized : normalized + 180
    }

    private static func rowIsInsideBoundary(_ row: MulchRow, boundary: FieldBoundary) -> Bool {
        let pointA = MKMapPoint(row.pointA)
        let pointB = MKMapPoint(row.pointB)
        let sampleCount = 32

        return (0...sampleCount).allSatisfy { sample in
            let fraction = Double(sample) / Double(sampleCount)
            let coordinate = MKMapPoint(
                x: pointA.x + (pointB.x - pointA.x) * fraction,
                y: pointA.y + (pointB.y - pointA.y) * fraction
            ).coordinate
            return contains(coordinate, in: boundary)
        }
    }

    private static func segmentsIntersect(_ first: MulchRow, _ second: MulchRow) -> Bool {
        let firstStart = MKMapPoint(first.pointA)
        let firstEnd = MKMapPoint(first.pointB)
        let secondStart = MKMapPoint(second.pointA)
        let secondEnd = MKMapPoint(second.pointB)

        let o1 = orientation(firstStart, firstEnd, secondStart)
        let o2 = orientation(firstStart, firstEnd, secondEnd)
        let o3 = orientation(secondStart, secondEnd, firstStart)
        let o4 = orientation(secondStart, secondEnd, firstEnd)

        if differentSigns(o1, o2), differentSigns(o3, o4) { return true }
        if abs(o1) <= intersectionTolerance, point(secondStart, liesOnSegmentFrom: firstStart, to: firstEnd) { return true }
        if abs(o2) <= intersectionTolerance, point(secondEnd, liesOnSegmentFrom: firstStart, to: firstEnd) { return true }
        if abs(o3) <= intersectionTolerance, point(firstStart, liesOnSegmentFrom: secondStart, to: secondEnd) { return true }
        if abs(o4) <= intersectionTolerance, point(firstEnd, liesOnSegmentFrom: secondStart, to: secondEnd) { return true }
        return false
    }

    private static func pointIsOnBoundary(_ point: MKMapPoint, polygon: [MKMapPoint], latitude: Double) -> Bool {
        let tolerance = boundaryToleranceMeters / MKMetersPerMapPointAtLatitude(latitude)

        for index in polygon.indices {
            let start = polygon[index]
            let end = polygon[(index + 1) % polygon.count]
            if distanceFromPoint(point, toSegmentFrom: start, to: end) <= tolerance {
                return true
            }
        }
        return false
    }

    private static func distanceFromPoint(_ point: MKMapPoint, toSegmentFrom start: MKMapPoint, to end: MKMapPoint) -> Double {
        let vectorX = end.x - start.x
        let vectorY = end.y - start.y
        let squaredLength = vectorX * vectorX + vectorY * vectorY
        guard squaredLength > 0 else { return hypot(point.x - start.x, point.y - start.y) }

        let position = min(1, max(0, ((point.x - start.x) * vectorX + (point.y - start.y) * vectorY) / squaredLength))
        let projectedX = start.x + position * vectorX
        let projectedY = start.y + position * vectorY
        return hypot(point.x - projectedX, point.y - projectedY)
    }

    private static func lineIntersections(
        origin: MKMapPoint,
        directionX: Double,
        directionY: Double,
        polygon: [MKMapPoint]
    ) -> [Double] {
        var values: [Double] = []

        for index in polygon.indices {
            let edgeStart = polygon[index]
            let edgeEnd = polygon[(index + 1) % polygon.count]
            let edgeX = edgeEnd.x - edgeStart.x
            let edgeY = edgeEnd.y - edgeStart.y
            let denominator = cross(directionX, directionY, edgeX, edgeY)
            guard abs(denominator) > intersectionTolerance else { continue }

            let originToEdgeX = edgeStart.x - origin.x
            let originToEdgeY = edgeStart.y - origin.y
            let linePosition = cross(originToEdgeX, originToEdgeY, edgeX, edgeY) / denominator
            let edgePosition = cross(originToEdgeX, originToEdgeY, directionX, directionY) / denominator

            if edgePosition >= -intersectionTolerance, edgePosition <= 1 + intersectionTolerance {
                values.append(linePosition)
            }
        }

        return values.sorted().reduce(into: []) { result, value in
            if let last = result.last, abs(last - value) < 0.01 { return }
            result.append(value)
        }
    }

    private static func cross(_ ax: Double, _ ay: Double, _ bx: Double, _ by: Double) -> Double {
        ax * by - ay * bx
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
