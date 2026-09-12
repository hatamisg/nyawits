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
                                .font(.system(size: 52)).foregroundStyle(VigorPalette.color(observation.ndre))
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
                                // Kolom lama: satu-satunya pengisinya data simulasi.
                                Text(observation.ndreSource == "simulated"
                                     ? "SKOR SIMULASI" : "SKOR LAMA").font(.caption.bold())
                                Text(ndre, format: .number.precision(.fractionLength(3))).font(.largeTitle.bold().monospacedDigit())
                            }
                            Spacer()
                            Circle().fill(VigorPalette.color(ndre)).frame(width: 56, height: 56)
                        }
                        VigorLegend(caption: "Skala simulasi")
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
