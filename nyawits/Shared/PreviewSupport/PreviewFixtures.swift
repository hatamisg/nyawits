#if DEBUG
import Foundation

/// Canvas-only fixtures. No files, permissions, or live measurements are needed.
@MainActor
enum PreviewFixtures {
    static let demo = NDREDemoFactory.makeField()
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
