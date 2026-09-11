import Foundation

/// Keeps the existing filenames, ISO-8601 dates and atomic write behavior.
@MainActor
final class LocalFieldRepository: FieldRepository {
    private let fileManager: FileManager
    private let rootURL: URL
    private var photosURL: URL { rootURL.appendingPathComponent("PlantPhotos", isDirectory: true) }
    private var dataURL: URL { rootURL.appendingPathComponent("mapped-fields.json") }
    private var selectionURL: URL { rootURL.appendingPathComponent("active-field.json") }

    init(fileManager: FileManager = .default, storageRoot: URL? = nil) {
        self.fileManager = fileManager
        let support = (try? fileManager.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)) ?? fileManager.temporaryDirectory
        rootURL = storageRoot ?? support.appendingPathComponent("NyawitsMapping", isDirectory: true)
    }

    func prepare() throws {
        try fileManager.createDirectory(at: photosURL, withIntermediateDirectories: true)
    }

    func loadFields() throws -> [MappedField] {
        guard fileManager.fileExists(atPath: dataURL.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([MappedField].self, from: Data(contentsOf: dataURL))
    }

    func saveFields(_ fields: [MappedField]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(fields).write(to: dataURL, options: .atomic)
    }

    func loadSelection() throws -> ActiveFieldSidecar? {
        guard fileManager.fileExists(atPath: selectionURL.path) else { return nil }
        return try JSONDecoder().decode(ActiveFieldSidecar.self, from: Data(contentsOf: selectionURL))
    }

    func saveSelection(_ selection: ActiveFieldSidecar) throws {
        try JSONEncoder().encode(selection).write(to: selectionURL, options: .atomic)
    }

    func savePhoto(_ data: Data, observationID: UUID) throws -> String {
        let filename = "\(observationID.uuidString).jpg"
        try data.write(to: photosURL.appendingPathComponent(filename), options: .atomic)
        return filename
    }

    private func safeURL(_ filename: String) -> URL? {
        guard filename == (filename as NSString).lastPathComponent,
              !filename.isEmpty, filename != ".", filename != ".." else { return nil }
        let url = photosURL.appendingPathComponent(filename)
        guard (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) == nil else { return nil }
        return url
    }

    func deletePhoto(named filename: String) -> Bool {
        guard let url = safeURL(filename) else { return false }
        guard fileManager.fileExists(atPath: url.path) else { return true }
        do { try fileManager.removeItem(at: url); return true } catch { return false }
    }

    func photoURL(filename: String) -> URL? {
        guard let url = safeURL(filename), fileManager.fileExists(atPath: url.path) else { return nil }
        return url
    }
}
