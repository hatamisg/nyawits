import MapKit
import SwiftUI

struct FieldOverviewMap: View {
    let field: MappedField
    var cornerRadius: CGFloat? = nil
    /// nil shows all rows; an empty set shows no rows. This never mutates the field.
    var visibleRowNumbers: Set<Int>? = nil
    var onSelect: ((PlantObservation) -> Void)? = nil

    private var visibleRows: [MappedRow] {
        field.rows.filter { visibleRowNumbers?.contains($0.number) ?? true }
    }

    private var visibleObservations: [PlantObservation] {
        let rowIDs = Set(visibleRows.map(\.id))
        return field.observations.filter {
            $0.status == .captured && $0.projectedCoordinate != nil
                && rowIDs.contains($0.rowID)
        }
    }

    private var countLabel: String {
        "\(visibleObservations.count) " + (field.isDemo == true ? "tanaman simulasi" : "foto")
    }

    var body: some View {
        Canvas { context, size in
            let geometry = FieldOverviewGeometry(field: field, size: CGSize(width: size.width, height: size.height - 82), padding: 22)
            context.translateBy(x: 0, y: 36)
            drawBoundary(context: &context, geometry: geometry)
        }
        .overlay {
            GeometryReader { proxy in
                let geometry = FieldOverviewGeometry(field: field,
                    size: CGSize(width: proxy.size.width, height: proxy.size.height - 82), padding: 22)
                let grouped = Dictionary(grouping: visibleObservations, by: \.rowID)
                ZStack {
                    ForEach(visibleRows) { row in
                        FieldHeatmapRow(row: row, observations: grouped[row.id] ?? [],
                                        geometry: geometry,
                                        pointRadius: field.observations.count > 60 ? 4.5 : 6)
                    }
                }
                .offset(y: 36)
            }
            .allowsHitTesting(false)
        }
        .overlay {
            GeometryReader { proxy in
                Rectangle().fill(.white.opacity(0.001)).contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { event in
                        let location = event.location
                        let geometry = FieldOverviewGeometry(field: field,
                            size: CGSize(width: proxy.size.width, height: proxy.size.height - 82), padding: 22)
                        let candidates = visibleObservations
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
                       title: countLabel)
                Spacer()
                Label("U", systemImage: "location.north.fill")
                    .font(.caption.weight(.bold)).foregroundStyle(.white)
            }
            .padding(12)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            if visibleObservations.contains(where: { $0.ndre != nil }) {
                NDRELegend().foregroundStyle(.white.opacity(0.85)).padding(.horizontal, 18).padding(.bottom, 14).allowsHitTesting(false)
            } else {
                Text(visibleObservations.isEmpty ? "Belum ada titik pada baris yang ditampilkan" : "Ketuk titik untuk melihat foto • posisi perkiraan")
                    .font(.caption2).foregroundStyle(.white).padding(.bottom, 14)
            }
        }
        .clipShape(
            cornerRadius != nil
                ? AnyShape(RoundedRectangle(cornerRadius: cornerRadius!, style: .continuous))
                : AnyShape(Rectangle())
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Peta \(field.name), \(countLabel)")
        .accessibilityChildren {
            ForEach(visibleObservations) { observation in
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

#if DEBUG
#Preview {
    FieldOverviewMap(field: PreviewFixtures.demo).frame(height: 380).padding()
}
#Preview("Hanya baris 3") {
    FieldOverviewMap(field: PreviewFixtures.demo, visibleRowNumbers: [3]).frame(height: 380)
}
#Preview("Baris 2 dan 5") {
    FieldOverviewMap(field: PreviewFixtures.demo, visibleRowNumbers: [2, 5]).frame(height: 380)
}
#Preview("Tanpa baris") {
    FieldOverviewMap(field: PreviewFixtures.demo, visibleRowNumbers: []).frame(height: 380)
}
#endif
