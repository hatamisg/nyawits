import Foundation

/// Mengikuti perilaku `LocalFieldRepository`: root yang sama, tanggal ISO-8601,
/// tulis atomik, dan nama berkas yang dijaga dari path traversal.
@MainActor
final class LocalScanSessionRepository: ScanSessionRepository {
    private let fileManager: FileManager
    private let rootURL: URL
    private var framesURL: URL { rootURL.appendingPathComponent("ScanFrames", isDirectory: true) }
    private var dataURL: URL { rootURL.appendingPathComponent("scan-sessions.json") }

    init(fileManager: FileManager = .default, storageRoot: URL? = nil) {
        self.fileManager = fileManager
        let support = (try? fileManager.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)) ?? fileManager.temporaryDirectory
        rootURL = storageRoot ?? support.appendingPathComponent("NyawitsMapping", isDirectory: true)
    }

    func prepare() throws {
        try fileManager.createDirectory(at: framesURL, withIntermediateDirectories: true)
    }

    func loadSessions() throws -> [ScanSession] {
        guard fileManager.fileExists(atPath: dataURL.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ScanSession].self, from: Data(contentsOf: dataURL))
    }

    func saveSessions(_ sessions: [ScanSession]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(sessions).write(to: dataURL, options: .atomic)
    }

    /// Frame mentah disalin ke penyimpanan app supaya arsip tidak bergantung
    /// pada berkas asal yang bisa dipindah atau dihapus pengguna.
    func saveFrame(_ data: Data, frameID: UUID, pathExtension: String) throws -> String {
        let suffix = sanitizedExtension(pathExtension)
        let filename = suffix.isEmpty ? frameID.uuidString : "\(frameID.uuidString).\(suffix)"
        try data.write(to: framesURL.appendingPathComponent(filename), options: .atomic)
        return filename
    }

    /// Hanya huruf dan angka: ekstensi datang dari berkas pilihan pengguna.
    private func sanitizedExtension(_ value: String) -> String {
        let lowered = value.lowercased()
        let allowed = lowered.filter { $0.isLetter || $0.isNumber }
        return String(allowed.prefix(8))
    }

    private func safeURL(_ filename: String) -> URL? {
        guard filename == (filename as NSString).lastPathComponent,
              !filename.isEmpty, filename != ".", filename != ".." else { return nil }
        let url = framesURL.appendingPathComponent(filename)
        guard (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) == nil else { return nil }
        return url
    }

    func deleteFrame(named filename: String) -> Bool {
        guard let url = safeURL(filename) else { return false }
        guard fileManager.fileExists(atPath: url.path) else { return true }
        do { try fileManager.removeItem(at: url); return true } catch { return false }
    }

    func frameURL(filename: String) -> URL? {
        guard let url = safeURL(filename), fileManager.fileExists(atPath: url.path) else { return nil }
        return url
    }
}
