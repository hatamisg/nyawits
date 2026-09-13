import SwiftUI

struct FieldMappingCard: View {
    let field: MappedField
    let onContinue: () -> Void
    @EnvironmentObject private var scanStore: ScanSessionStore
    @State private var selected: PlantObservation?
    @State private var showsPlants = false
    @State private var showsScanSessions = false
    @ScaledMetric(relativeTo: .headline) private var primaryButtonHeight: CGFloat = 54
    @ScaledMetric(relativeTo: .caption2) private var statusBadgeHeight: CGFloat = 28
    @ScaledMetric(relativeTo: .headline) private var metricDividerHeight: CGFloat = 38

    private var summary: FieldProgressSummary {
        FieldListPresentation.progressSummary(for: field)
    }

    var body: some View {
        VStack(spacing: 0) {
            FieldOverviewMap(field: field, onSelect: { selected = $0 })
                .frame(height: 380)

            VStack(alignment: .leading, spacing: 16) {
                header
                metrics
                if field.isDemo == true {
                    Text("Skor acak untuk pratinjau tampilan. Bukan hasil pengukuran, dan bukan nilai klorofil.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: summary.fraction).tint(.green)
                        Text("\(summary.numerator)/\(summary.denominator) sisi baris ditandai selesai")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if field.isDemo != true && (field.lowConfidenceCount > 0 || field.unpositionedPhotoCount > 0) {
                    locationNotice
                }

                Button { if field.isDemo == true { showsPlants = true } else { onContinue() } } label: {
                    Label(field.isDemo == true ? "Jelajahi 200 Tanaman" : buttonTitle,
                          systemImage: field.isDemo == true ? "leaf.fill" : "camera.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: primaryButtonHeight)
                        .background(Color.green, in: Capsule())
                }
                // Satu tombol, dua tujuan: sesi pindai menumpang di sini supaya
                // kartu tidak bertambah elemen. Muncul untuk semua kebun nyata,
                // karena satu petak sesi bisa berdiri sendiri tanpa foto.
                if field.isDemo != true {
                    Menu {
                        Button("Foto & detail tanaman") { showsPlants = true }
                            .disabled(field.observations.isEmpty)
                        Button("Sesi pindai") { showsScanSessions = true }
                    } label: {
                        Text("Lihat detail kebun")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }
            .padding(18)
            .background(.background)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.06), radius: 14, y: 5)
        .sheet(item: $selected) { PlantObservationDetailView(observation: $0, field: field) }
        .sheet(isPresented: $showsPlants) { FieldPlantListView(field: field) }
        .sheet(isPresented: $showsScanSessions) {
            NavigationStack {
                ScanSessionListView(fieldID: field.id, fieldName: field.name, showsCloseButton: true)
            }
            .environmentObject(scanStore)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(field.name)
                    .font(.title3.weight(.bold))
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(field.isDemo == true ? "SIMULASI" : (field.capturedPlantCount == 0 ? "BARU" : "TERSIMPAN"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.green)
                .padding(.horizontal, 10)
                .frame(height: statusBadgeHeight)
                .background(Color.green.opacity(0.12), in: Capsule())
        }
    }

    private var metrics: some View {
        HStack(spacing: 0) {
            metric(value: FieldMeasurementFormatter.area(field.areaSquareMeters), label: "Luas")
            Divider().frame(height: metricDividerHeight)
            metric(value: "\(field.rows.count)", label: "Baris")
            Divider().frame(height: metricDividerHeight)
            if field.isDemo == true {
                metric(value: String(format: "%.2f", field.previewVigorValues.reduce(0, +) / Double(max(1, field.previewVigorValues.count))), label: "Rata-rata simulasi")
            } else {
                metric(value: "\(field.capturedPlantCount)", label: "Foto")
            }
        }
    }

    private var locationNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.fill")
                .foregroundStyle(.orange)
            Text(locationNoticeText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 12)
    }

    private var statusText: String {
        guard field.capturedPlantCount > 0 else { return "Siap untuk pemetaan foto" }
        return "\(field.capturedPlantCount) tanaman pada \(field.mappedRowCount) baris"
    }

    private var buttonTitle: String {
        field.observations.isEmpty ? "Mulai Foto Tanaman" : "Lanjutkan Pemetaan"
    }

    private var locationNoticeText: String {
        if field.unpositionedPhotoCount > 0 {
            return "\(field.unpositionedPhotoCount) foto belum memiliki posisi. Foto tetap tersimpan."
        }
        return "\(field.lowConfidenceCount) posisi masih berupa perkiraan GPS."
    }
}

#if DEBUG
#Preview {
    ScrollView { FieldMappingCard(field: PreviewFixtures.demo, onContinue: {}).padding() }.previewStores()
}
#endif
