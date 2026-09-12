import Foundation

enum FieldStoreError: Equatable, Error {
    case fieldNotFound
    case invalidName
    case invalidPlan
    case storageFailure
    case dataLoadFailed
    case revisionStale
    case captureStale
}

enum FieldDeleteWarning: Equatable {
    case photoCleanupIncomplete
    case selectionRestoreFailed
}

struct FieldDeleteOutcome: Equatable {
    var warnings: [FieldDeleteWarning] = []
}

struct ActiveFieldSidecar: Codable, Equatable {
    var fieldID: UUID?
    var isDemo: Bool? = nil
}


/// Boundary between application state and persistent storage.
@MainActor
protocol FieldRepository {
    func prepare() throws
    func loadFields() throws -> [MappedField]
    func saveFields(_ fields: [MappedField]) throws
    func loadSelection() throws -> ActiveFieldSidecar?
    func saveSelection(_ selection: ActiveFieldSidecar) throws
    func savePhoto(_ data: Data, observationID: UUID) throws -> String
    func deletePhoto(named filename: String) -> Bool
    func photoURL(filename: String) -> URL?
}
