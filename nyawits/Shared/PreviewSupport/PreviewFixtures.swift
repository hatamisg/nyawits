#if DEBUG
import Foundation
import SwiftUI

/// Canvas-only fixtures. No files, permissions, or live measurements are needed.
@MainActor
enum PreviewFixtures {
    static let demo = VigorDemoFactory.makeField()
    static var field: MappedField {
        var value = demo
        value.name = "Kebun Utama"
        value.isDemo = false
        return value
    }
    static var boundary: FieldBoundary { field.plan.boundary }
    static var archive: ArchivedFieldMapping {
        ArchivedFieldMapping(snapshotOf: field, revisionID: field.id,
                             archivedAt: field.updatedAt, versionCreatedAt: field.createdAt)
    }
    static var fieldWithHistory: MappedField {
        var value = field
        value.archivedMappings = [archive]
        return value
    }
    static func store(empty: Bool = false) -> FieldMappingStore {
        FieldMappingStore(repository: PreviewFieldRepository(fields: empty ? [] : [field]))
    }
    static func scanStore() -> ScanSessionStore {
        ScanSessionStore(repository: PreviewScanSessionRepository())
    }
    /// `ScheduleSettingsStore` hanya punya seam berkas, jadi preview diarahkan
    /// ke folder sementara yang unik agar tidak menyentuh data perangkat.
    static func scheduleStore() -> ScheduleSettingsStore {
        ScheduleSettingsStore(storageRoot: FileManager.default.temporaryDirectory
            .appendingPathComponent("nyawits-preview-schedule-\(UUID().uuidString)", isDirectory: true))
    }
    static func areaModel() -> FieldAreaSelectionViewModel {
        FieldAreaSelectionViewModel(initialBoundary: boundary)
    }
    static func rowModel() -> MulchRowSetupViewModel {
        MulchRowSetupViewModel(boundary: boundary, rowCount: 10, rotationDegrees: 0)
    }
    static func captureModel() -> PlantCaptureViewModel {
        PlantCaptureViewModel(fieldID: field.id, fieldName: field.name, plan: field.plan)
    }
}

extension View {
    /// Menyuntikkan seluruh store yang dibutuhkan pohon tampilan utama.
    /// Dipakai preview agar penambahan store baru cukup diubah di satu tempat.
    @MainActor
    func previewStores(_ store: FieldMappingStore? = nil) -> some View {
        environmentObject(store ?? PreviewFixtures.store())
            .environmentObject(PreviewFixtures.scanStore())
            .environmentObject(PreviewFixtures.scheduleStore())
    }
}

@MainActor
private final class PreviewScanSessionRepository: ScanSessionRepository {
    private var sessions: [ScanSession] = []
    func prepare() throws {}
    func loadSessions() throws -> [ScanSession] { sessions }
    func saveSessions(_ sessions: [ScanSession]) throws { self.sessions = sessions }
    func saveFrame(_ data: Data, frameID: UUID, pathExtension: String) throws -> String {
        "\(frameID.uuidString).\(pathExtension)"
    }
    func deleteFrame(named filename: String) -> Bool { true }
    func frameURL(filename: String) -> URL? { nil }
}

@MainActor
private final class PreviewFieldRepository: FieldRepository {
    private var fields: [MappedField]
    private var selection: ActiveFieldSidecar?
    init(fields: [MappedField]) {
        self.fields = fields
        selection = ActiveFieldSidecar(fieldID: fields.first?.id, isDemo: false)
    }
    func prepare() throws {}
    func loadFields() throws -> [MappedField] { fields }
    func saveFields(_ fields: [MappedField]) throws { self.fields = fields }
    func loadSelection() throws -> ActiveFieldSidecar? { selection }
    func saveSelection(_ selection: ActiveFieldSidecar) throws { self.selection = selection }
    func savePhoto(_ data: Data, observationID: UUID) throws -> String { observationID.uuidString }
    func deletePhoto(named filename: String) -> Bool { true }
    func photoURL(filename: String) -> URL? { nil }
}
#endif
