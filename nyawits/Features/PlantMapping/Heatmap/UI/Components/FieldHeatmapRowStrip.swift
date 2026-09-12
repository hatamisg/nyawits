import SwiftUI

/// Compact, horizontal presentation of one row for cards and summaries.
///
/// This deliberately does not use the row's map coordinates or field rotation.
/// It only presents the already-stored plant order, so a compact card cannot
/// change the mapping geometry, camera data, or persistence model.
struct FieldHeatmapRowStrip: View {
    let rowNumber: Int
    let side: PlantCaptureSide
    let plants: [PlantObservation]

    init(row: MappedRow, observations: [PlantObservation], side: PlantCaptureSide) {
        rowNumber = row.number
        self.side = side
        // `plantSequence` is captured data, not a UI index. Keep it intact.
        plants = observations
            .filter { $0.rowID == row.id && $0.side == side && $0.status == .captured }
            .sorted { $0.plantSequence < $1.plantSequence }
    }

    var body: some View {
        Group {
            if plants.isEmpty {
                ContentUnavailableView(
                    "Belum ada tanaman tercatat",
                    systemImage: "leaf",
                    description: Text("Baris \(rowNumber) • \(side.title)"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 74)
            } else {
                GeometryReader { proxy in
                    let diameter = min(30, max(12, proxy.size.width / CGFloat(plants.count) * 0.48))
                    HStack(spacing: 0) {
                        ForEach(plants) { plant in
                            FieldHeatmapRowStripPlant(plant: plant, diameter: diameter)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 74)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Baris \(rowNumber), \(side.title), \(plants.count) tanaman")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let measured = plants.filter { $0.ndre != nil }.count
        return measured == 0 ? "Belum ada nilai NDRE" : "\(measured) tanaman memiliki nilai NDRE"
    }
}

private struct FieldHeatmapRowStripPlant: View {
    let plant: PlantObservation
    let diameter: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.secondary.opacity(0.16))
                .frame(width: 1, height: 10)
            Circle()
                .fill(NDREPalette.color(plant.ndre))
                .overlay(Circle().strokeBorder(.white.opacity(0.72), lineWidth: 0.8))
                .frame(width: diameter, height: diameter)
            Rectangle()
                .fill(.secondary.opacity(0.16))
                .frame(width: 1, height: 10)
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Baris lurus untuk kartu") {
    let field = PreviewFixtures.demo
    if let row = field.rows.first(where: { $0.number == 3 }) {
        FieldHeatmapRowStrip(row: row, observations: field.observations, side: .left)
            .padding()
    }
}

#Preview("Belum ada data") {
    let field = PreviewFixtures.demo
    if let row = field.rows.first {
        FieldHeatmapRowStrip(row: row, observations: [], side: .left)
            .padding()
    }
}
#endif
