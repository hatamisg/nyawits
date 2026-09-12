import Foundation

/// The composition root is the only place that chooses concrete persistence.
extension FieldMappingStore {
    convenience init(fileManager: FileManager = .default, storageRoot: URL? = nil) {
        self.init(repository: LocalFieldRepository(fileManager: fileManager, storageRoot: storageRoot))
    }
}
