import MapKit
import SwiftUI

struct FieldOverviewMap: View {
    let field: MappedField
    var cornerRadius: CGFloat? = nil
    var onSelect: ((PlantObservation) -> Void)? = nil

    var body: some View {
        Canvas { context, size in
            let geometry = FieldOverviewGeometry(field: field, size: CGSize(width: size.width, height: size.height - 82), padding: 22)
            context.translateBy(x: 0, y: 36)
            drawBoundary(context: &context, geometry: geometry)
            drawRows(context: &context, geometry: geometry)
            drawObservations(context: &context, geometry: geometry)
        }
        .overlay {
            GeometryReader { proxy in
                Rectangle().fill(.white.opacity(0.001)).contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { event in
                        let location = event.location
                        let geometry = FieldOverviewGeometry(field: field,
                            size: CGSize(width: proxy.size.width, height: proxy.size.height - 82), padding: 22)
                        let candidates = field.observations.filter { $0.status == .captured && $0.projectedCoordinate != nil }
                        let nearest = candidates.min { lhs, rhs in
                            distance(lhs, to: location, geometry: geometry) < distance(rhs, to: location, geometry: geometry)
                        }
                        if let nearest, distance(nearest, to: location, geometry: geometry) <= 22 { onSelect?(nearest) }
                    })
            }
        }
        .background {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.22, blue: 0.13),
                    Color(red: 0.16, green: 0.34, blue: 0.19)
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
        }
        .overlay(alignment: .topLeading) {
            HStack(spacing: 12) {
                legend(color: field.isDemo == true ? .yellow : .cyan,
                       title: field.isDemo == true ? "200 tanaman simulasi" : "\(field.capturedPlantCount) foto")
                Spacer()
                Label("U", systemImage: "location.north.fill")
                    .font(.caption.weight(.bold)).foregroundStyle(.white)
            }
            .padding(12)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            if !field.ndreValues.isEmpty {
                NDRELegend().foregroundStyle(.white.opacity(0.85)).padding(.horizontal, 18).padding(.bottom, 14).allowsHitTesting(false)
            } else {
                Text("Ketuk titik untuk melihat foto • posisi perkiraan")
                    .font(.caption2).foregroundStyle(.white).padding(.bottom, 14)
            }
        }
        .clipShape(
            cornerRadius != nil
                ? AnyShape(RoundedRectangle(cornerRadius: cornerRadius!, style: .continuous))
                : AnyShape(Rectangle())
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(field.isDemo == true ? "Peta demo, 200 tanaman simulasi" : "Peta \(field.name), \(field.capturedPlantCount) tanaman telah difoto")
        .accessibilityChildren {
            ForEach(field.observations.filter { $0.status == .captured && $0.projectedCoordinate != nil }) { observation in
                Button("Baris \(observation.rowNumber), \(observation.side.title), tanaman \(observation.plantSequence)") {
                    onSelect?(observation)
                }
            }
        }
    }

    private func distance(_ observation: PlantObservation, to point: CGPoint, geometry: FieldOverviewGeometry) -> Double {
        guard let coordinate = observation.projectedCoordinate?.coordinate else { return .infinity }
        let center = geometry.point(for: coordinate)
        return hypot(center.x - point.x, center.y + 36 - point.y)
    }

    private func drawBoundary(context: inout GraphicsContext, geometry: FieldOverviewGeometry) {
        guard let first = field.boundaryPoints.first else { return }
        var path = Path()
        path.move(to: geometry.point(for: first.coordinate))
        for point in field.boundaryPoints.dropFirst() {
            path.addLine(to: geometry.point(for: point.coordinate))
        }
        path.closeSubpath()
        context.fill(path, with: .color(.white.opacity(0.12)))
        context.stroke(path, with: .color(.white.opacity(0.92)), lineWidth: 2.5)
    }

    private func drawRows(context: inout GraphicsContext, geometry: FieldOverviewGeometry) {
        for row in field.rows {
            var path = Path()
            path.move(to: geometry.point(for: row.pointA.coordinate))
            path.addLine(to: geometry.point(for: row.pointB.coordinate))
            context.stroke(path, with: .color(.white.opacity(0.23)), lineWidth: 1)
        }
    }

    private func drawObservations(context: inout GraphicsContext, geometry: FieldOverviewGeometry) {
        for observation in field.observations {
            guard observation.status == .captured,
                  let coordinate = observation.projectedCoordinate?.coordinate else { continue }
            let center = geometry.point(for: coordinate)
            let radius = field.observations.count > 60 ? 4.5 : 6.0
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

            let isEstimated = (observation.horizontalAccuracyMeters ?? .infinity) > 10
                || observation.trackingQuality != .normal
            context.fill(
                Path(ellipseIn: rect),
                with: .color(observation.ndre != nil ? NDREPalette.color(observation.ndre) : (isEstimated ? .gray : .cyan))
            )
            context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.7)), lineWidth: 0.8)
        }
    }

    private func legend(color: Color, title: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(.black.opacity(0.42), in: Capsule())
    }
}
