import SwiftUI

/// Layar hasil: urutan kunjungan, ditambah batas klaim yang wajib ikut.
///
/// Tidak ada satuan µg/cm², tidak ada persentase kesehatan, dan tidak ada
/// perbandingan dengan sesi lain. Yang sah adalah urutan di dalam sesi ini.
struct ScanRankingView: View {
    let sessionID: UUID

    @EnvironmentObject private var scanStore: ScanSessionStore
    @State private var isShowingAccuracy = false

    private var session: ScanSession? { scanStore.session(id: sessionID) }

    var body: some View {
        List {
            switch scanStore.ranking(for: sessionID) {
            case let .success(ranking)?:
                rankingSection(ranking)
                warningSection(ranking)
                claimSection
                modelSection
                excludedSection(ranking)
            case let .failure(error)?:
                Section {
                    Label(message(for: error), systemImage: "exclamationmark.octagon.fill")
                        .foregroundStyle(.red)
                }
            case nil:
                Section {
                    Text("Sesi tidak ditemukan.").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Peringkat kunjungan")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func rankingSection(_ ranking: SessionRanking) -> some View {
        Section {
            if let session {
                ForEach(ScanSessionPresentation.rows(for: session, ranking: ranking)) { row in
                    MeasurementRowView(row: row)
                }
            }
        } header: {
            Text("Urutan kunjungan")
        } footer: {
            Text("Kunjungi dari nomor 1. Urutan ini hanya berlaku di dalam sesi ini dan kebun ini.")
        }
    }

    @ViewBuilder
    private func warningSection(_ ranking: SessionRanking) -> some View {
        if !ranking.warnings.isEmpty {
            Section("Catatan sesi ini") {
                ForEach(ranking.warnings.indices, id: \.self) { index in
                    Label(
                        ScanSessionPresentation.warningText(ranking.warnings[index]),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(.orange)
                }
            }
        }
    }

    private var claimSection: some View {
        Section {
            ForEach(ScanSessionPresentation.claimLimits, id: \.self) { line in
                Label(line, systemImage: "info.circle")
                    .font(.footnote)
                    .labelStyle(.titleAndIcon)
            }
            DisclosureGroup("Seberapa tepat alat ini?", isExpanded: $isShowingAccuracy) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(ScanSessionPresentation.accuracyClaim)
                        .font(.footnote)
                    ForEach(ScanSessionPresentation.accuracyCaveats, id: \.self) { caveat in
                        Label(caveat, systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .font(.footnote)
        } header: {
            Text("Batas klaim")
        }
    }

    @ViewBuilder
    private var modelSection: some View {
        switch scanStore.vigorModel {
        case let .success(model):
            Section {
                // Dibaca dari berkas, bukan ditulis ulang sebagai string Swift,
                // supaya kalibrasi ulang yang mengubah peringatannya langsung terbawa.
                ForEach(model.warnings, id: \.self) { warning in
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Validasi lapangan", value: model.fieldValidationText)
                    .font(.caption)
                if let featureSet = model.featureSetLabel {
                    LabeledContent("Himpunan fitur", value: featureSet)
                        .font(.caption)
                }
            } header: {
                Text("Peringatan model")
            } footer: {
                Text("Baris di atas dibaca langsung dari berkas kalibrasi, jadi kalau modelnya dilatih ulang, peringatannya ikut berubah tanpa memperbarui aplikasi.")
            }
        case let .failure(error):
            Section("Peringatan model") {
                Label(message(for: error), systemImage: "exclamationmark.octagon.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private func excludedSection(_ ranking: SessionRanking) -> some View {
        if !ranking.excluded.isEmpty {
            Section("Petak yang tidak dihitung") {
                ForEach(ranking.excluded) { item in
                    Text(item.reason.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func message(for error: Error) -> String {
        if let error = error as? RankingError { return error.message }
        if let error = error as? VigorModelError { return error.message }
        if let error = error as? BundleJSONResource.LoadError { return error.message }
        return "Peringkat tidak dapat dihitung."
    }
}
