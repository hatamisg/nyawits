import Foundation

@main
struct ArchitectureSmokeTests {
    @MainActor
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let disk = LocalFieldRepository(storageRoot: root)
        try disk.prepare()
        let initial = try disk.loadFields()
        precondition(initial.isEmpty)
        let demo = NDREDemoFactory.makeField()
        try disk.saveFields([demo])
        let restored = try disk.loadFields()
        precondition(restored.count == 1 && restored[0].id == demo.id)
        precondition(restored[0].observations.count == demo.observations.count)
        try disk.saveSelection(ActiveFieldSidecar(fieldID: demo.id))
        let selection = try disk.loadSelection()
        precondition(selection?.fieldID == demo.id)
        let filename = try disk.savePhoto(Data([1, 2, 3]), observationID: UUID())
        precondition(disk.photoURL(filename: filename) != nil)
        precondition(!disk.deletePhoto(named: "../outside.jpg"))
        precondition(disk.deletePhoto(named: filename))
        precondition(disk.deletePhoto(named: filename))
        let memory = FailingRepository()
        let store = FieldMappingStore(repository: memory)
        precondition(!store.upsert(demo))
        precondition(store.fields.isEmpty, "Failed save must not publish candidate data")
        print("PASS: JSON round-trip, selection, photos, traversal, failed-write rollback")
    }
}

@MainActor
private final class FailingRepository: FieldRepository {
    func prepare() throws {}
    func loadFields() throws -> [MappedField] { [] }
    func saveFields(_ fields: [MappedField]) throws { throw CocoaError(.fileWriteUnknown) }
    func loadSelection() throws -> ActiveFieldSidecar? { nil }
    func saveSelection(_ selection: ActiveFieldSidecar) throws {}
    func savePhoto(_ data: Data, observationID: UUID) throws -> String { throw CocoaError(.fileWriteUnknown) }
    func deletePhoto(named filename: String) -> Bool { false }
    func photoURL(filename: String) -> URL? { nil }
}
