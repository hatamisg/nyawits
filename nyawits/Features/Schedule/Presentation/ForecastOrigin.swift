import Foundation

/// Dari mana ramalan yang sedang ditampilkan berasal.
///
/// Ini bukan detail teknis: menampilkan salinan lama tanpa mengatakannya sama
/// saja dengan berbohong tentang cuaca besok.
nonisolated enum ForecastOrigin: Equatable {
    case live(fetchedAt: Date)
    case cachedCopy(fetchedAt: Date, reason: String)

    var isStale: Bool {
        if case .cachedCopy = self { return true }
        return false
    }
}

nonisolated enum ForecastState: Equatable {
    case idle
    case loading
    case loaded(HourlyForecast, ForecastOrigin)
    /// Gagal DAN tidak ada salinan sama sekali. Jangan pernah menampilkan
    /// status hijau dari keadaan ini.
    case failed(String)
}
