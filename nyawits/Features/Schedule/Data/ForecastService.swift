import Combine
import Foundation

/// Menyatukan klien jaringan dan salinan di disk.
///
/// Urutannya selalu: coba jaringan, simpan salinan kalau berhasil; kalau gagal
/// pakai salinan lama DAN katakan itu salinan lama; kalau salinan pun tidak ada,
/// gagalkan dengan jelas. Tidak ada jalan dari sini menuju status HIJAU tanpa
/// data — itu satu-satunya kegagalan yang benar-benar berbahaya di sini.
@MainActor
final class ForecastService: ObservableObject {
    @Published private(set) var state: ForecastState = .idle

    private let client: OpenMeteoClient
    private let cache: ForecastCache

    /// `cache` dibangun di dalam badan init, bukan sebagai nilai default
    /// parameter: nilai default dievaluasi di konteks nonisolated, sedangkan
    /// `ForecastCache` terikat MainActor.
    init(client: OpenMeteoClient = OpenMeteoClient(), cache: ForecastCache? = nil) {
        self.client = client
        self.cache = cache ?? ForecastCache()
    }

    /// Untuk pratinjau dan uji: seluruh salinan diisolasi ke root sendiri.
    convenience init(storageRoot: URL?) {
        self.init(client: OpenMeteoClient(), cache: ForecastCache(storageRoot: storageRoot))
    }

    func load(
        latitude: Double = OpenMeteoClient.defaultLatitude,
        longitude: Double = OpenMeteoClient.defaultLongitude,
        forecastDays: Int = OpenMeteoClient.defaultForecastDays
    ) async {
        state = .loading
        do {
            let result = try await client.fetch(
                latitude: latitude, longitude: longitude, forecastDays: forecastDays
            )
            cache.save(payload: result.payload, latitude: latitude, longitude: longitude)
            state = .loaded(result.forecast, .live(fetchedAt: Date()))
        } catch {
            state = fallback(after: error)
        }
    }

    /// Sengaja tidak `private`: "selamat dari jaringan mati" adalah perilaku
    /// yang harus bisa diuji tanpa mematikan jaringan sungguhan.
    func fallback(after error: Error) -> ForecastState {
        let reason = (error as? OpenMeteoClient.ClientError)?.message
            ?? "Ramalan cuaca tidak dapat diambil."
        guard let cached = cache.load(),
              let forecast = try? OpenMeteoClient.parse(cached.payload) else {
            return .failed(reason + " Tidak ada salinan tersimpan, jadi jadwal cuaca belum bisa ditampilkan.")
        }
        return .loaded(forecast, .cachedCopy(fetchedAt: cached.fetchedAt, reason: reason))
    }
}
