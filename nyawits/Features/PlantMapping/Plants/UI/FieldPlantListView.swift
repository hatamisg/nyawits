import SwiftUI

struct FieldPlantListView: View {
    @Environment(\.dismiss) private var dismiss
    let field: MappedField
    @State private var selected: PlantObservation?
    var body: some View {
        NavigationStack {
            List {
                ForEach(field.rows) { row in
                    Section("Baris \(row.number)") {
                        ForEach(field.observations.filter { $0.rowID == row.id }) { observation in
                            Button { selected = observation } label: {
                                HStack {
                                    Circle().fill(NDREPalette.color(observation.ndre)).frame(width: 14, height: 14)
                                    Text("\(observation.side.title) · Tanaman \(observation.plantSequence)")
                                    Spacer()
                                    if let value = observation.ndre { Text(value, format: .number.precision(.fractionLength(2))).monospacedDigit() }
                                    else if observation.status == .skipped { Text("Dilewati").font(.caption) }
                                    Image(systemName: "chevron.right").font(.caption)
                                }.foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(field.isDemo == true ? "200 tanaman demo" : "Foto tanaman")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tutup") { dismiss() } } }
            .sheet(item: $selected) { PlantObservationDetailView(observation: $0, field: field) }
        }
    }
}
