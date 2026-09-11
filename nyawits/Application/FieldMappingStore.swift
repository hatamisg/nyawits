import Combine
import Foundation

@MainActor
final class FieldMappingStore: ObservableObject {
    @Published private(set) var fields: [MappedField] = []
    @Published private(set) var activeFieldID: UUID?
    @Published private(set) var isDemoSelected = false
    @Published private(set) var lastErrorMessage: String?

    private let repository: any FieldRepository

    /// True saat file `mapped-fields.json` gagal dimuat: mutasi yang dapat
    /// menimpa file dengan array kosong diblokir sampai kondisi diselesaikan.
    private(set) var dataLoadFailed = false

    /// Kebun aktif dari `activeFieldID`, hanya kebun nyata (demo disaring).
    var activeField: MappedField? {
        guard let activeFieldID else { return nil }
        return fields.first(where: { $0.id == activeFieldID && $0.isDemo != true })
    }

    init(repository: any FieldRepository) {
        self.repository = repository
        do {
            try repository.prepare()
            load()
            loadSelectionSidecar()
        } catch {
            lastErrorMessage = "Saved field data couldn’t be opened."
            dataLoadFailed = true
        }
    }

    // MARK: - Queries

    func field(id: UUID) -> MappedField? {
        fields.first(where: { $0.id == id })
    }

    func suggestedFieldName() -> String {
        "Field \(fields.count + 1)"
    }

    // MARK: - Selection

    /// Pilih kebun aktif: validasi ID nyata, tulis sidecar atomik dulu, baru publish ID.
    /// No-op bila sudah aktif; tidak menyentuh updatedAt atau data kebun.
    /// Kegagalan menulis sidecar tetap di layar asal dengan pesan di lastErrorMessage.
    @discardableResult
    func selectField(id: UUID) -> Result<Void, FieldStoreError> {
        if let current = activeFieldID, current == id {
            return .success(())
        }
        guard !dataLoadFailed else { return .failure(.dataLoadFailed) }
        guard let target = fields.first(where: { $0.id == id && $0.isDemo != true }) else {
            lastErrorMessage = "Kebun ini sudah tidak tersedia. Perbarui daftar lalu pilih kembali."
            return .failure(.fieldNotFound)
        }
        do {
            try writeSelectionSidecar(fieldID: target.id)
        } catch {
            lastErrorMessage = "Pilihan kebun belum tersimpan. Periksa ruang penyimpanan lalu coba lagi."
            return .failure(.storageFailure)
        }
        lastErrorMessage = nil
        activeFieldID = target.id
        isDemoSelected = false
        return .success(())
    }

    /// Demo is a presentation choice, never a persisted garden or camera target.
    @discardableResult
    func selectDemo() -> Result<Void, FieldStoreError> {
        if isDemoSelected { return .success(()) }
        do {
            try writeSelectionSidecar(fieldID: nil, isDemo: true)
        } catch {
            lastErrorMessage = "Pilihan demo belum tersimpan. Coba lagi."
            return .failure(.storageFailure)
        }
        activeFieldID = nil
        isDemoSelected = true
        if !dataLoadFailed { lastErrorMessage = nil }
        return .success(())
    }

    // MARK: - Rename

    /// Resolve latest record saat commit; hanya `name` (dan `updatedAt` menurut
    /// perilaku store lama) yang berubah. Nama sama setelah trim = no-op.
    @discardableResult
    func renameField(id: UUID, name: String) -> Result<Void, FieldStoreError> {
        guard !dataLoadFailed else { return .failure(.dataLoadFailed) }
        guard let index = fields.firstIndex(where: { $0.id == id }) else {
            return .failure(.fieldNotFound)
        }
        let current = fields[index]
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.invalidName) }
        guard current.name != trimmed else { return .success(()) }

        var candidate = current
        candidate.name = trimmed
        candidate.updatedAt = Date()
        var candidates = fields
        candidates[index] = candidate
        candidates.sort { $0.updatedAt > $1.updatedAt }
        guard persistFields(candidates) else { return .failure(.storageFailure) }
        fields = candidates
        return .success(())
    }

    // MARK: - Delete

    /// Hapus transaksional: metadata atomik dulu, publish, pilih fallback bila
    /// target aktif, baru cleanup foto best-effort. Gagal metadata tidak
    /// mengubah apa pun; gagal sidecar setelah metadata sukses tidak di-rollback.
    @discardableResult
    func deleteField(id: UUID) -> Result<FieldDeleteOutcome, FieldStoreError> {
        guard !dataLoadFailed else { return .failure(.dataLoadFailed) }
        guard let target = fields.first(where: { $0.id == id }) else {
            return .failure(.fieldNotFound)
        }
        var warnings: [FieldDeleteWarning] = []

        let targetFilenames = collectPhotoFilenames(of: target)
        let candidates = fields.filter { $0.id != id }
        guard persistFields(candidates) else { return .failure(.storageFailure) }
        fields = candidates

        if activeFieldID == id {
            let fallback = FieldOrdering.sortFields(candidates.filter { $0.isDemo != true })
                .first?.id
            do {
                try writeSelectionSidecar(fieldID: fallback)
            } catch {
                warnings.append(.selectionRestoreFailed)
            }
            activeFieldID = fallback
        }

        let remainingReferences = Set(fields.flatMap { collectPhotoFilenames(of: $0) })
        var cleanupIncomplete = false
        for filename in targetFilenames where !remainingReferences.contains(filename) {
            if !safeDeletePhoto(named: filename) {
                cleanupIncomplete = true
            }
        }
        if cleanupIncomplete {
            warnings.append(.photoCleanupIncomplete)
        }
        return .success(FieldDeleteOutcome(warnings: warnings))
    }

    // MARK: - Edit nama + geometri (versi pemetaan)

    /// Transaksi edit kebun. Nama saja → rename; plan identik (setelah
    /// canonical comparison) → no-op; plan berbeda → snapshot riwayat bila
    /// versi lama punya observasi/progres, lalu versi aktif baru. Satu write
    /// atomik; gagal write tidak mengubah in-memory maupun disk.
    @discardableResult
    func updateField(id: UUID, draft: FieldEditDraft, baseRevision: UUID?) -> Result<Void, FieldStoreError> {
        guard !dataLoadFailed else { return .failure(.dataLoadFailed) }
        guard let index = fields.firstIndex(where: { $0.id == id }) else {
            return .failure(.fieldNotFound)
        }
        let current = fields[index]
        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.invalidName) }
        guard current.mappingRevisionID == baseRevision else { return .failure(.revisionStale) }
        guard FieldPlanValidator.isValid(draft.plan) else { return .failure(.invalidPlan) }

        let currentPlan = current.plan
        let geometryChanged = !FieldGeometryComparator.isEquivalent(currentPlan, draft.plan)
        let nameChanged = current.name != trimmed

        if !geometryChanged {
            guard nameChanged else { return .success(()) }
            var candidate = current
            candidate.name = trimmed
            candidate.updatedAt = Date()
            var candidates = fields
            candidates[index] = candidate
            candidates.sort { $0.updatedAt > $1.updatedAt }
            guard persistFields(candidates) else { return .failure(.storageFailure) }
            fields = candidates
            return .success(())
        }

        let now = Date()
        var candidate = current
        var candidates = fields

        let hasProgress = !current.observations.isEmpty
            || !(current.completedRowSides ?? []).isEmpty
            || current.resumeRowID != nil
            || current.resumeSide != nil
        if hasProgress {
            let snapshot = ArchivedFieldMapping(
                snapshotOf: current,
                revisionID: current.mappingRevisionID ?? UUID(),
                archivedAt: now,
                versionCreatedAt: current.mappingVersionCreatedAt ?? current.createdAt
            )
            if candidate.archivedMappings == nil { candidate.archivedMappings = [] }
            candidate.archivedMappings?.append(snapshot)
        }

        candidate.boundaryID = draft.plan.boundary.id
        candidate.boundaryPoints = draft.plan.boundary.points.map { GeoCoordinate($0.coordinate) }
        candidate.areaSquareMeters = draft.plan.boundary.areaSquareMeters
        candidate.perimeterMeters = draft.plan.boundary.perimeterMeters
        candidate.rotationDegrees = draft.plan.rotationDegrees
        candidate.rows = draft.plan.rows.enumerated().map { MappedRow(row: $0.element, number: $0.offset + 1) }
        candidate.observations = []
        candidate.completedRowSides = []
        candidate.resumeRowID = nil
        candidate.resumeSide = nil
        candidate.name = trimmed
        candidate.mappingRevisionID = UUID()
        candidate.mappingVersionCreatedAt = now
        candidate.updatedAt = now

        candidates[index] = candidate
        candidates.sort { $0.updatedAt > $1.updatedAt }
        guard persistFields(candidates) else { return .failure(.storageFailure) }
        fields = candidates
        return .success(())
    }

    // MARK: - Capture (foto / resume)

    /// Simpan progress capture pada record terbaru dengan preservasi riwayat.
    /// Create first-save yang sah membuat record baru. Resume terhadap field
    /// yang hilang atau revision yang sudah berubah ditolak (stale), bukan
    /// membangkitkan snapshot lama. Mengembalikan revision aktif terbaru.
    @discardableResult
    func saveCapture(
        fieldID: UUID,
        fieldName: String,
        plan: MulchRowPlan,
        observations: [PlantObservation],
        completedRowSides: [String],
        resumeRowID: UUID?,
        resumeSide: PlantCaptureSide?,
        fieldCreatedAt: Date,
        baseRevisionID: UUID?,
        allowsCreation: Bool
    ) -> Result<UUID?, FieldStoreError> {
        guard !dataLoadFailed else { return .failure(.dataLoadFailed) }

        if let existing = fields.first(where: { $0.id == fieldID }) {
            guard existing.mappingRevisionID == baseRevisionID else {
                return .failure(.captureStale)
            }
            var candidate = existing
            candidate.observations = observations
            candidate.completedRowSides = completedRowSides
            candidate.resumeRowID = resumeRowID
            candidate.resumeSide = resumeSide
            candidate.updatedAt = Date()

            var candidates = fields
            if let index = candidates.firstIndex(where: { $0.id == fieldID }) {
                candidates[index] = candidate
            }
            candidates.sort { $0.updatedAt > $1.updatedAt }
            guard persistFields(candidates) else { return .failure(.storageFailure) }
            fields = candidates
            return .success(candidate.mappingRevisionID)
        }

        guard allowsCreation else { return .failure(.captureStale) }
        var newField = MappedField(
            id: fieldID,
            name: fieldName,
            plan: plan,
            observations: observations,
            createdAt: fieldCreatedAt
        )
        newField.completedRowSides = completedRowSides
        newField.resumeRowID = resumeRowID
        newField.resumeSide = resumeSide
        newField.mappingRevisionID = UUID()
        newField.mappingVersionCreatedAt = fieldCreatedAt
        newField.updatedAt = Date()

        var candidates = fields
        candidates.append(newField)
        candidates.sort { $0.updatedAt > $1.updatedAt }
        guard persistFields(candidates) else { return .failure(.storageFailure) }
        fields = candidates
        return .success(newField.mappingRevisionID)
    }

    // MARK: - Kontrak lama (dipertahankan agar capture/tests tidak direwrite)

    @discardableResult
    func upsert(_ field: MappedField) -> Bool {
        guard !dataLoadFailed else {
            lastErrorMessage = "Perubahan belum tersimpan. Periksa ruang penyimpanan lalu coba lagi."
            return false
        }
        let previous = fields
        var updatedField = field
        updatedField.updatedAt = Date()

        if let index = fields.firstIndex(where: { $0.id == field.id }) {
            fields[index] = updatedField
        } else {
            fields.append(updatedField)
        }
        fields.sort { $0.updatedAt > $1.updatedAt }
        if persistFields(fields) { return true }
        fields = previous
        return false
    }

    func savePhoto(_ data: Data, observationID: UUID) -> String? {
        do {
            return try repository.savePhoto(data, observationID: observationID)
        } catch {
            lastErrorMessage = "The plant photo couldn’t be saved."
            return nil
        }
    }

    func deletePhoto(filename: String?) {
        guard let filename else { return }
        _ = repository.deletePhoto(named: filename)
    }

    func photoURL(filename: String?) -> URL? {
        guard let filename else { return nil }
        return repository.photoURL(filename: filename)
    }

    // MARK: - Private: loading & persistence

    private func load() {
        do {
            fields = try repository.loadFields().sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            lastErrorMessage = "Saved field data is damaged and couldn’t be loaded."
            dataLoadFailed = true
        }
    }

    /// Pulihkan pilihan aktif dari sidecar. ID invalid/missing memilih fallback
    /// deterministik (updatedAt terbaru, tie-break UUID). Sidecar rusak hanya
    /// menghidupkan ulang pilihan; file fields tidak tersentuh.
    private func loadSelectionSidecar() {
        do {
            guard let decoded = try repository.loadSelection() else {
                normalizeActiveSelection(stored: nil, sidecarExisted: false)
                return
            }
            if decoded.isDemo == true {
                activeFieldID = nil
                isDemoSelected = true
            } else {
                normalizeActiveSelection(stored: decoded.fieldID, sidecarExisted: true)
            }
        } catch {
            normalizeActiveSelection(stored: nil, sidecarExisted: true)
        }
    }

    private func normalizeActiveSelection(stored: UUID?, sidecarExisted: Bool) {
        let realFields = fields.filter { $0.isDemo != true }
        let storedValid = stored.flatMap { id in
            realFields.first(where: { $0.id == id })?.id
        }
        if let storedValid {
            activeFieldID = storedValid
            try? writeSelectionSidecar(fieldID: storedValid)
            return
        }
        let fallback = FieldOrdering.sortFields(realFields).first?.id
        if fallback != nil || sidecarExisted {
            activeFieldID = fallback
            try? writeSelectionSidecar(fieldID: fallback)
        } else {
            activeFieldID = nil
        }
    }

    private func writeSelectionSidecar(fieldID: UUID?, isDemo: Bool = false) throws {
        try repository.saveSelection(ActiveFieldSidecar(fieldID: fieldID, isDemo: isDemo ? true : nil))
    }

    /// Tulis kandidat array fields secara atomik tanpa mengubah in-memory state.
    private func writeFields(_ candidates: [MappedField]) throws {
        try repository.saveFields(candidates)
    }

    private func persistFields(_ candidates: [MappedField]) -> Bool {
        do {
            try writeFields(candidates)
            lastErrorMessage = nil
            return true
        } catch {
            lastErrorMessage = "Perubahan belum tersimpan. Periksa ruang penyimpanan lalu coba lagi."
            return false
        }
    }

    // MARK: - Photo cleanup helpers

    private func collectPhotoFilenames(of field: MappedField) -> Set<String> {
        var filenames = Set(field.observations.compactMap(\.imageFilename))
        for archive in field.archivedMappings ?? [] {
            filenames.formUnion(archive.observations.compactMap(\.imageFilename))
        }
        return filenames
    }

    /// Hapus foto lokal dengan nama basename aman. Path absolute, traversal
    /// dan symlink keluar photosURL ditolak. File yang sudah tidak ada =
    /// idempotent sukses.
    private func safeDeletePhoto(named filename: String) -> Bool {
        repository.deletePhoto(named: filename)
    }
}
