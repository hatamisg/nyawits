import Foundation

/// Salinan ramalan terakhir yang berhasil diambil.
nonisolated struct CachedForecast: Codable, Equatable {
    let fetchedAt: Date
    let latitude: Double
    let longitude: Double
    let payload: Data
}

/// Simpanan salinan ramalan di disk.
///
/// Kalau jaringan gagal, salinan lama dipakai DAN dikatakan bahwa itu salinan
/// lama. Kalau salinan pun tidak ada, gagalkan dengan jelas — jangan pernah
/// menampilkan status HIJAU dari data kosong.
@MainActor
final class ForecastCache {
    private let fileManager: FileManager
    private let rootURL: URL
    private var cacheURL: URL { rootURL.appendingPathComponent("forecast-cache.json") }

    init(fileManager: FileManager = .default, storageRoot: URL? = nil) {
        self.fileManager = fileManager
        let support = (try? fileManager.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)) ?? fileManager.temporaryDirectory
        rootURL = storageRoot ?? support.appendingPathComponent("NyawitsMapping", isDirectory: true)
    }

    func load() -> CachedForecast? {
        guard fileManager.fileExists(atPath: cacheURL.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CachedForecast.self, from: Data(contentsOf: cacheURL))
    }

    @discardableResult
    func save(payload: Data, latitude: Double, longitude: Double, fetchedAt: Date = Date()) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let cached = CachedForecast(
            fetchedAt: fetchedAt, latitude: latitude, longitude: longitude, payload: payload
        )
        guard let data = try? encoder.encode(cached) else { return false }
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            try data.write(to: cacheURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
