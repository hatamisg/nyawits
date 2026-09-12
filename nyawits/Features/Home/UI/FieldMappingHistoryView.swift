import SwiftUI

/// Riwayat pemetaan (EDIT-GEOMETRY): daftar versi lama hanya-baca.
/// Tanpa CTA kamera/resume; kartu Home tetap satu kebun.
struct FieldMappingHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    let field: MappedField

    private var archives: [ArchivedFieldMapping] {
        field.archivedMappings ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(archives, id: \.revisionID) { archive in
                        NavigationLink {
                            FieldMappingVersionDetailView(field: field, archive: archive)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(archive.nameAtArchive)
                                    .font(.headline)
                                    .lineLimit(2)
                                Text(archive.archivedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("\(archive.rows.count) baris · \(archive.capturedPhotoCount) foto")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityElement(children: .combine)
                    }
                } footer: {
                    Text("Foto dan progres versi lama tersimpan apa adanya dan tidak dapat dilanjutkan.")
                }
            }
            .navigationTitle("Riwayat pemetaan (\(archives.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
    }
}

/// Peta + foto versi lama, readonly: geometri asli, tanpa CTA kamera.
struct FieldMappingVersionDetailView: View {
    let field: MappedField
    let archive: ArchivedFieldMapping

    @State private var selected: PlantObservation?

    /// Representasi MappedField versi arsip untuk komponen readonly.
    private var versionField: MappedField {
        var version = MappedField(
            id: field.id,
            name: archive.nameAtArchive,
            plan: archive.plan,
            observations: archive.observations,
            createdAt: archive.createdAt,
            updatedAt: archive.archivedAt
        )
        version.isDemo = false
        version.completedRowSides = archive.completedRowSides
        version.resumeRowID = archive.resumeRowID
        version.resumeSide = archive.resumeSide
        version.mappingRevisionID = archive.revisionID
        version.mappingVersionCreatedAt = archive.createdAt
        return version
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                FieldOverviewMap(field: versionField, cornerRadius: 24, onSelect: { selected = $0 })
                    .frame(height: 320)
                    .padding(.horizontal, 16)

                if versionField.observations.isEmpty {
                    Text("Versi ini tidak memiliki foto.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    FieldPlantListViewInline(field: versionField)
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(archive.nameAtArchive)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { observation in
            PlantObservationDetailView(observation: observation, field: versionField)
        }
    }
}

/// Daftar foto versi arsip (readonly) untuk ditanam di scroll view.
struct FieldPlantListViewInline: View {
    let field: MappedField
    @State private var selected: PlantObservation?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(field.rows) { row in
                let observations = field.observations.filter { $0.rowID == row.id }
                if !observations.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Baris \(row.number)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                        ForEach(observations) { observation in
                            Button { selected = observation } label: {
                                HStack {
                                    Circle()
                                        .fill(VigorPalette.color(observation.ndre))
                                        .frame(width: 14, height: 14)
                                        .accessibilityHidden(true)
                                    Text("\(observation.side.title) · Tanaman \(observation.plantSequence)")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if let value = observation.ndre {
                                        Text(value, format: .number.precision(.fractionLength(2)))
                                            .monospacedDigit()
                                            .foregroundStyle(.secondary)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        Divider().padding(.leading, 16)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
    }
}

#if DEBUG
#Preview("Riwayat kosong") { NavigationStack { FieldMappingHistoryView(field: PreviewFixtures.field) }.previewStores() }
#Preview("Riwayat tersimpan") { NavigationStack { FieldMappingHistoryView(field: PreviewFixtures.fieldWithHistory) }.previewStores() }
#Preview("Detail versi") { NavigationStack { FieldMappingVersionDetailView(field: PreviewFixtures.field, archive: PreviewFixtures.archive) }.previewStores() }
#Preview("Daftar tanaman inline") { NavigationStack { FieldPlantListViewInline(field: PreviewFixtures.demo) }.previewStores() }
#endif
