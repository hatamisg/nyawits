import Foundation

/// The composition root is the only place that chooses concrete persistence.
extension ScanSessionStore {
    convenience init(fileManager: FileManager = .default, storageRoot: URL? = nil) {
        self.init(repository: LocalScanSessionRepository(fileManager: fileManager, storageRoot: storageRoot))
    }
}
