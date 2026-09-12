import SwiftUI

/// One geographic row: its guide line and captured plant markers.
/// Read-only inputs preserve the original row/observation IDs and coordinates.
/// The parent owns selection so overlapping rows share one nearest-point hit test.
struct FieldHeatmapRow: View {
    let row: MappedRow
    let observations: [PlantObservation]
    let geometry: FieldOverviewGeometry
    var pointRadius: CGFloat = 4.5

    var body: some View {
        Canvas { context, _ in
            var line = Path()
            line.move(to: geometry.point(for: row.pointA.coordinate))
            line.addLine(to: geometry.point(for: row.pointB.coordinate))
            context.stroke(line, with: .color(.white.opacity(0.23)), lineWidth: 1)

            for observation in observations {
                guard observation.rowID == row.id,
                      observation.status == .captured,
                      let coordinate = observation.projectedCoordinate?.coordinate else { continue }
                let center = geometry.point(for: coordinate)
                let rect = CGRect(x: center.x - pointRadius, y: center.y - pointRadius,
                                  width: pointRadius * 2, height: pointRadius * 2)
                let isEstimated = (observation.horizontalAccuracyMeters ?? .infinity) > 10
                    || observation.trackingQuality != .normal
                let color = observation.ndre != nil
                    ? PlantHealthPalette.color(observation.ndre) : (isEstimated ? Color.gray : Color.cyan)
                context.fill(Path(ellipseIn: rect), with: .color(color))
                context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.7)), lineWidth: 0.8)
            }
        }
        .accessibilityHidden(true) // The map exposes selectable observations to VoiceOver.
    }
}

#if DEBUG
#Preview("Komponen baris 3") {
    GeometryReader { proxy in
        let field = PreviewFixtures.demo
        if let row = field.rows.first(where: { $0.number == 3 }) {
            FieldHeatmapRow(row: row, observations: field.observations,
                            geometry: FieldOverviewGeometry(field: field, size: proxy.size))
        }
    }
    .frame(height: 300)
    .background(Color(red: 0.08, green: 0.22, blue: 0.13))
}
#endif
