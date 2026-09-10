import SwiftUI

struct PlantObservationDetailView: View {
    @EnvironmentObject private var store: FieldMappingStore
    @Environment(\.dismiss) private var dismiss
    let observation: PlantObservation
    let field: MappedField

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let url = store.photoURL(filename: observation.imageFilename),
                       let photo = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: photo).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 24))
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: field.isDemo == true ? "leaf.fill" : "photo")
                                .font(.system(size: 52)).foregroundStyle(NDREPalette.color(observation.ndre))
                            Text(field.isDemo == true ? "Tanaman simulasi" : "Foto tidak tersedia")
                                .font(.headline)
                            Text(field.isDemo == true ? "Contoh data untuk melihat pemetaan. Tidak ada foto atau pengukuran sensor nyata." : "Metadata posisi tetap dapat dilihat di bawah.")
                                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(30)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 24))
                    }
                    Text("Baris \(observation.rowNumber) · \(observation.side.title) · Tanaman \(observation.plantSequence)")
                        .font(.title3.bold())
                    if observation.sideReferenceVersion == nil {
                        Text("Data lama: sisi kiri/kanan belum memiliki acuan arah tetap.").font(.caption).foregroundStyle(.secondary)
                    }
                    if let ndre = observation.ndre {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(observation.ndreSource == "simulated" ? "NDRE SIMULASI" : "NDRE").font(.caption.bold())
                                Text(ndre, format: .number.precision(.fractionLength(3))).font(.largeTitle.bold().monospacedDigit())
                            }
                            Spacer()
                            Circle().fill(NDREPalette.color(ndre)).frame(width: 56, height: 56)
                        }
                        NDRELegend()
                    }
                    LabeledContent("Waktu", value: observation.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Posisi", value: positionDescription)
                    if let coordinate = observation.projectedCoordinate {
                        Text(String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude))
                            .font(.callout.monospaced()).textSelection(.enabled)
                    }
                    if let accuracy = observation.positionUncertaintyMeters ?? observation.horizontalAccuracyMeters {
                        Text(String(format: "Perkiraan ketidakpastian posisi ±%.1f m. Titik mengikuti baris; posisi pohon belum diukur langsung.", accuracy))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(20)
            }
            .navigationTitle("Detail tanaman").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tutup") { dismiss() } } }
        }
    }

    private var positionDescription: String {
        switch observation.positionMethod {
        case "demo": "Koordinat simulasi"
        case "gpsAR": "GPS + perpindahan kamera"
        default: observation.projectedCoordinate == nil ? "Belum tersedia" : "Perkiraan GPS"
        }
    }
}

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
