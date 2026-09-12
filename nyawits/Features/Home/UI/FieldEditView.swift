import SwiftUI

/// Modal `Edit kebun` (PLAN §2, EDIT-GEOMETRY alur pengguna): nama, ringkasan
/// luas/baris/rotasi, tombol Ubah batas dan Ubah baris. Draft milik satu view
/// ini; store hanya ditulis satu kali ketika Simpan dikonfirmasi.
struct FieldEditView: View {
    @EnvironmentObject private var store: FieldMappingStore
    @Environment(\.dismiss) private var dismiss

    let fieldID: UUID
    /// Dipanggil sekali setelah commit sukses: (fieldID, nama baru ter-trim).
    let onSaved: (UUID, String) -> Void

    @State private var draftName: String
    @State private var draftPlan: MulchRowPlan
    @State private var originalName: String
    @State private var originalPlan: MulchRowPlan
    @State private var baseRevision: UUID?
    @State private var hasProgress: Bool

    @State private var isEditingBoundary = false
    @State private var isEditingRows = false
    @State private var pendingBoundary: FieldBoundary?
    @State private var nameError: String?
    @State private var commitError: String?
    @State private var isShowingNewMappingDialog = false
    @State private var isShowingDiscardDialog = false
    @State private var isShowingReloadDialog = false

    init(field: MappedField, onSaved: @escaping (UUID, String) -> Void) {
        self.fieldID = field.id
        self.onSaved = onSaved
        _draftName = State(initialValue: field.name)
        _draftPlan = State(initialValue: field.plan)
        _originalName = State(initialValue: field.name)
        _originalPlan = State(initialValue: field.plan)
        _baseRevision = State(initialValue: field.mappingRevisionID)
        _hasProgress = State(
            initialValue: !field.observations.isEmpty
                || !(field.completedRowSides ?? []).isEmpty
                || field.resumeRowID != nil
        )
    }

    private var trimmedName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Perubahan dinilai secara semantik (toleransi numerik), bukan UUID editor.
    private var geometryChanged: Bool {
        !FieldGeometryComparator.isEquivalent(originalPlan, draftPlan)
    }

    private var draftChanged: Bool {
        trimmedName != originalName || geometryChanged
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nama kebun", text: $draftName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Nama kebun")
                    if let nameError {
                        Label(nameError, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Nama kebun")
                } footer: {
                    Text("Kebun lain boleh memakai nama yang sama.")
                }

                Section {
                    LabeledContent("Luas", value: FieldMeasurementFormatter.area(draftPlan.boundary.areaSquareMeters))
                    LabeledContent("Baris", value: "\(draftPlan.rows.count)")
                    LabeledContent("Rotasi", value: "\(Int(draftPlan.rotationDegrees.rounded()))°")

                    Button {
                        isEditingBoundary = true
                    } label: {
                        Label("Ubah batas", systemImage: "square.dashed")
                    }
                    .accessibilityHint("Buka editor peta dengan titik batas saat ini")

                    Button {
                        pendingBoundary = draftPlan.boundary
                        isEditingRows = true
                    } label: {
                        Label("Ubah baris", systemImage: "tablecells")
                    }
                    .accessibilityHint("Atur ulang jumlah dan rotasi baris pada batas saat ini")
                } header: {
                    Text("Pemetaan")
                } footer: {
                    Text("Mengubah batas atau baris memulai pemetaan baru; foto dan progres lama tetap tersedia di Riwayat pemetaan.")
                }

                if let commitError {
                    Section {
                        Label(commitError, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit kebun")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") {
                        if draftChanged {
                            isShowingDiscardDialog = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan", action: save)
                }
            }
            .interactiveDismissDisabled(draftChanged)
            .navigationDestination(isPresented: $isEditingBoundary) {
                FieldAreaSelectionView(
                    title: "Ubah Batas",
                    subtitle: "Geser titik, atau ketuk peta untuk menambah",
                    initialBoundary: draftPlan.boundary,
                    onCancel: { isEditingBoundary = false },
                    onConfirmed: { newBoundary in
                        pendingBoundary = newBoundary
                        isEditingBoundary = false
                        isEditingRows = true
                    }
                )
            }
            .navigationDestination(isPresented: $isEditingRows) {
                MulchRowSetupView(
                    boundary: pendingBoundary ?? draftPlan.boundary,
                    initialRowCount: draftPlan.rows.count,
                    initialRotationDegrees: draftPlan.rotationDegrees,
                    onBack: { isEditingRows = false },
                    onConfirmed: { plan in
                        draftPlan = plan
                        isEditingRows = false
                    }
                )
            }
            .confirmationDialog(
                "Simpan pemetaan baru?",
                isPresented: $isShowingNewMappingDialog,
                titleVisibility: .visible
            ) {
                Button("Simpan pemetaan baru") {
                    commit(confirmingNewMapping: true)
                }
                Button("Batal", role: .cancel) {}
            } message: {
                Text("Perubahan batas atau baris akan memulai pemetaan baru. Foto dan progres lama tetap tersedia di Riwayat pemetaan.")
            }
            .confirmationDialog(
                "Buang perubahan?",
                isPresented: $isShowingDiscardDialog,
                titleVisibility: .visible
            ) {
                Button("Buang perubahan", role: .destructive) { dismiss() }
                Button("Lanjut mengedit", role: .cancel) {}
            } message: {
                Text("Perubahan nama, batas, atau baris yang belum disimpan akan hilang.")
            }
            .alert("Pemetaan berubah", isPresented: $isShowingReloadDialog) {
                Button("Muat ulang", role: .destructive) { reloadBase() }
                Button("Batal", role: .cancel) {}
            } message: {
                Text("Kebun ini berubah di luar editor. Muat ulang untuk melanjutkan dari data terbaru; perubahan di editor akan dibuang.")
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else {
            nameError = "Nama tidak boleh kosong."
            return
        }
        nameError = nil
        if geometryChanged, hasProgress {
            isShowingNewMappingDialog = true
            return
        }
        commit(confirmingNewMapping: false)
    }

    private func commit(confirmingNewMapping: Bool) {
        // Geometri no-op tidak butuh konfirmasi pemetaan baru.
        let requiresConfirmation = geometryChanged && hasProgress
        guard !requiresConfirmation || confirmingNewMapping else {
            isShowingNewMappingDialog = true
            return
        }
        let draft = FieldEditDraft(name: trimmedName, plan: draftPlan)
        switch store.updateField(id: fieldID, draft: draft, baseRevision: baseRevision) {
        case .success:
            onSaved(fieldID, trimmedName)
            dismiss()
        case .failure(.revisionStale):
            commitError = nil
            isShowingReloadDialog = true
        case .failure(let error):
            commitError = Self.failureMessage(for: error, from: store)
        }
    }

    /// Muat ulang data dasar dari record terbaru; draft edit mengikuti data baru.
    private func reloadBase() {
        guard let latest = store.field(id: fieldID) else {
            commitError = "Kebun ini sudah tidak tersedia."
            return
        }
        originalName = latest.name
        originalPlan = latest.plan
        baseRevision = latest.mappingRevisionID
        draftName = latest.name
        draftPlan = latest.plan
        hasProgress = !latest.observations.isEmpty
            || !(latest.completedRowSides ?? []).isEmpty
            || latest.resumeRowID != nil
        commitError = nil
    }

    private static func failureMessage(for error: FieldStoreError, from store: FieldMappingStore) -> String {
        switch error {
        case .storageFailure:
            return store.lastErrorMessage ?? "Perubahan belum tersimpan. Periksa ruang penyimpanan lalu coba lagi."
        case .invalidName:
            return "Nama tidak boleh kosong."
        case .invalidPlan:
            return "Batas atau baris tidak valid. Periksa kembali pemetaan."
        case .dataLoadFailed:
            return "Data kebun gagal dimuat; perubahan dibatalkan demi keamanan data."
        case .fieldNotFound:
            return "Kebun ini sudah tidak tersedia."
        case .revisionStale, .captureStale:
            return "Kebun berubah di luar editor. Muat ulang untuk melanjutkan."
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { FieldEditView(field: PreviewFixtures.field, onSaved: { _, _ in }) }.previewStores()
}
#endif
