import Foundation

/// Klien ramalan Open-Meteo. Gratis, tanpa kunci API.
///
/// Ini SATU-SATUNYA bagian sistem yang menyentuh jaringan, dan ia BOLEH GAGAL:
/// seluruh fungsi inti lain bekerja luring karena sinyal kebun tidak andal.
nonisolated struct OpenMeteoClient {
    /// Batam. Dipakai kalau kebun belum punya koordinat sendiri.
    static let defaultLatitude = 1.10
    static let defaultLongitude = 104.05
    static let timeZoneIdentifier = "Asia/Jakarta"
    static let defaultForecastDays = 7

    enum ClientError: Error, Equatable {
        case invalidURL
        case transport(String)
        case badStatus(Int)
        case malformedPayload

        var message: String {
            switch self {
            case .invalidURL:
                "Alamat layanan ramalan tidak sah."
            case let .transport(detail):
                "Ramalan cuaca tidak dapat diambil: \(detail)"
            case let .badStatus(code):
                "Layanan ramalan menolak permintaan (kode \(code))."
            case .malformedPayload:
                "Balasan layanan ramalan tidak dapat dibaca."
            }
        }
    }

    static func makeURL(
        latitude: Double,
        longitude: Double,
        forecastDays: Int = defaultForecastDays
    ) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(
                name: "hourly",
                value: "precipitation,soil_moisture_1_to_3cm,soil_moisture_3_to_9cm,temperature_2m"
            ),
            URLQueryItem(name: "timezone", value: timeZoneIdentifier),
            URLQueryItem(name: "forecast_days", value: String(forecastDays))
        ]
        return components?.url
    }

    private struct Payload: Decodable {
        struct Hourly: Decodable {
            let time: [String]
            let precipitation: [Double?]?
            let soilMoisture3to9: [Double?]?
            let temperature2m: [Double?]?

            enum CodingKeys: String, CodingKey {
                case time
                case precipitation
                case soilMoisture3to9 = "soil_moisture_3_to_9cm"
                case temperature2m = "temperature_2m"
            }
        }

        let hourly: Hourly
    }

    /// Open-Meteo mengirim waktu lokal tanpa offset ("2026-09-12T16:00") karena
    /// parameter `timezone` sudah diminta, jadi ia diurai di zona yang sama.
    static func parse(_ data: Data) throws -> HourlyForecast {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            throw ClientError.malformedPayload
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        var times: [Date] = []
        var keptIndices: [Int] = []
        for (index, raw) in payload.hourly.time.enumerated() {
            guard let date = formatter.date(from: raw) else { continue }
            times.append(date)
            keptIndices.append(index)
        }
        guard !times.isEmpty else { throw ClientError.malformedPayload }

        func column(_ values: [Double?]?) -> [Double?] {
            keptIndices.map { index in
                guard let values, index < values.count else { return nil }
                return values[index]
            }
        }

        return HourlyForecast(
            times: times,
            precipitationMM: column(payload.hourly.precipitation),
            soilMoisture3to9: column(payload.hourly.soilMoisture3to9),
            temperature2m: column(payload.hourly.temperature2m)
        )
    }

    /// Mengembalikan ramalan sekaligus muatan mentahnya, supaya pemanggil bisa
    /// menyimpan salinan apa adanya untuk dipakai saat jaringan mati.
    func fetch(
        latitude: Double,
        longitude: Double,
        forecastDays: Int = defaultForecastDays,
        session: URLSession = .shared
    ) async throws -> (forecast: HourlyForecast, payload: Data) {
        guard let url = Self.makeURL(
            latitude: latitude, longitude: longitude, forecastDays: forecastDays
        ) else {
            throw ClientError.invalidURL
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw ClientError.transport(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ClientError.badStatus(http.statusCode)
        }
        return (try Self.parse(data), data)
    }
}
