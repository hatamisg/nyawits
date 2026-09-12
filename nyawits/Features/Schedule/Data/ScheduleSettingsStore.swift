import Combine
import Foundation

/// Tanggal semai dan pindah tanam per kebun.
///
/// Disimpan TERPISAH dari `MappedField` dengan sengaja: `Features/Schedule/`
/// tidak boleh bergantung pada `PlantMapping/`, dan geometri kebun yang sudah
/// berjalan tidak perlu disentuh untuk menambah dua tanggal. Kuncinya hanya
/// UUID kebun, bukan tipe dari subsistem lain.
nonisolated struct ScheduleSettings: Codable, Equatable, Identifiable {
    let fieldID: UUID
    // Optional additions keep existing on-device JSON readable.
    var sowingDate: Date? = nil
    var transplantDate: Date? = nil
    /// Pengamatan mengalahkan kalender: kalau bunga pertama sudah terlihat,
    /// tanggalnya yang menentukan peralihan fase.
    var firstFlowerDate: Date? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil

    var id: UUID { fieldID }

    init(fieldID: UUID) {
        self.fieldID = fieldID
    }

    /// Fase hanya bisa dihitung kalau tanggal semai sudah diisi.
    var isReady: Bool { sowingDate != nil }
}

nonisolated enum ScheduleSettingsError: Equatable, Error {
    case storageFailure
    case dataLoadFailed
    case transplantBeforeSowing

    var message: String {
        switch self {
        case .storageFailure:
            "Tanggal belum tersimpan. Periksa ruang penyimpanan lalu coba lagi."
        case .dataLoadFailed:
            "Data jadwal tidak dapat dibuka, jadi perubahan diblokir agar data lama tidak tertimpa."
        case .transplantBeforeSowing:
            "Tanggal pindah tanam mendahului tanggal semai. Periksa kembali kedua tanggalnya."
        }
    }
}

/// Mengikuti pola transaksi yang sama seperti store lain: susun kandidat,
/// tulis atomik, baru publish.
@MainActor
final class ScheduleSettingsStore: ObservableObject {
    @Published private(set) var settings: [ScheduleSettings] = []
    @Published private(set) var lastErrorMessage: String?

    private(set) var dataLoadFailed = false

    private let fileManager: FileManager
    private let rootURL: URL
    private var dataURL: URL { rootURL.appendingPathComponent("schedule-settings.json") }

    init(fileManager: FileManager = .default, storageRoot: URL? = nil) {
        self.fileManager = fileManager
        let support = (try? fileManager.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)) ?? fileManager.temporaryDirectory
        rootURL = storageRoot ?? support.appendingPathComponent("NyawitsMapping", isDirectory: true)
        load()
    }

    func settings(for fieldID: UUID) -> ScheduleSettings {
        settings.first(where: { $0.fieldID == fieldID }) ?? ScheduleSettings(fieldID: fieldID)
    }

    @discardableResult
    func update(_ updated: ScheduleSettings) -> Result<Void, ScheduleSettingsError> {
        guard !dataLoadFailed else { return .failure(.dataLoadFailed) }
        if let sowing = updated.sowingDate, let transplant = updated.transplantDate,
           transplant < sowing {
            return .failure(.transplantBeforeSowing)
        }

        var candidates = settings
        if let index = candidates.firstIndex(where: { $0.fieldID == updated.fieldID }) {
            guard candidates[index] != updated else { return .success(()) }
            candidates[index] = updated
        } else {
            candidates.append(updated)
        }

        guard persist(candidates) else { return .failure(.storageFailure) }
        settings = candidates
        return .success(())
    }

    private func load() {
        guard fileManager.fileExists(atPath: dataURL.path) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            settings = try decoder.decode([ScheduleSettings].self, from: Data(contentsOf: dataURL))
        } catch {
            lastErrorMessage = "Data jadwal rusak dan tidak dapat dimuat."
            dataLoadFailed = true
        }
    }

    private func persist(_ candidates: [ScheduleSettings]) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            try encoder.encode(candidates).write(to: dataURL, options: .atomic)
            lastErrorMessage = nil
            return true
        } catch {
            lastErrorMessage = "Tanggal belum tersimpan. Periksa ruang penyimpanan lalu coba lagi."
            return false
        }
    }
}
