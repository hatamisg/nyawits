import Foundation

/// Ambang gerbang cuaca, dibaca dari `Resources/Schedule/thresholds.json`.
///
/// NILAI AWAL, WAJIB DIKALIBRASI. Berkasnya menyatakan itu sendiri di `_catatan`;
/// tampilkan, jangan disembunyikan.
nonisolated struct FertilizerThresholds: Equatable {
    let washoutMM: Double
    let idealMinMM: Double
    let idealMaxMM: Double
    let washoutWindowHours: Int
    let dissolveWindowHours: Int
    let applicationHour: Int
    let notes: [String]

    static let resourceName = "thresholds"
    static let resourceSubdirectory = "Schedule"

    /// Fraksi ambang pencucian yang sudah dianggap "mendekati".
    static let approachingFraction = 0.6

    var approachingMM: Double { washoutMM * Self.approachingFraction }

    private struct Payload: Decodable {
        let hujanCuciMM: Double
        let hujanIdealMinMM: Double
        let hujanIdealMaksMM: Double
        let jendelaCuciJam: Int
        let jendelaLarutJam: Int
        let jamAplikasi: Int
        let catatan: [String]?

        enum CodingKeys: String, CodingKey {
            case hujanCuciMM = "hujan_cuci_mm"
            case hujanIdealMinMM = "hujan_ideal_min_mm"
            case hujanIdealMaksMM = "hujan_ideal_maks_mm"
            case jendelaCuciJam = "jendela_cuci_jam"
            case jendelaLarutJam = "jendela_larut_jam"
            case jamAplikasi = "jam_aplikasi"
            case catatan = "_catatan"
        }
    }

    enum LoadError: Error, Equatable {
        case malformedJSON
        var message: String { "Ambang gerbang cuaca tidak dapat dibaca." }
    }

    static func load(data: Data) throws -> FertilizerThresholds {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            throw LoadError.malformedJSON
        }
        return FertilizerThresholds(
            washoutMM: payload.hujanCuciMM,
            idealMinMM: payload.hujanIdealMinMM,
            idealMaxMM: payload.hujanIdealMaksMM,
            washoutWindowHours: payload.jendelaCuciJam,
            dissolveWindowHours: payload.jendelaLarutJam,
            applicationHour: payload.jamAplikasi,
            notes: payload.catatan ?? []
        )
    }

    static func loadFromBundle(_ bundle: Bundle = .main) throws -> FertilizerThresholds {
        try load(data: BundleJSONResource.data(
            named: resourceName,
            subdirectory: resourceSubdirectory,
            bundle: bundle
        ))
    }
}

/// Deret ramalan per jam. Nilai `nil` berarti ramalan tidak memuat jam itu.
nonisolated struct HourlyForecast: Equatable, Codable {
    var times: [Date]
    var precipitationMM: [Double?]
    var soilMoisture3to9: [Double?]
    var temperature2m: [Double?]

    var isEmpty: Bool { times.isEmpty }
}

nonisolated enum FertilizerStatus: String, Equatable, Codable {
    case green
    case yellow
    case red

    var title: String {
        switch self {
        case .green: "HIJAU"
        case .yellow: "KUNING"
        case .red: "MERAH"
        }
    }
}

nonisolated struct DayAssessment: Equatable, Identifiable {
    let date: Date
    let status: FertilizerStatus
    /// Kenapa statusnya begitu. Hanya soal curah hujan.
    let reason: String
    /// Apa yang sebaiknya dilakukan. Di sinilah lengas dan suhu masuk.
    let action: String
    let washoutMM: Double?
    let dissolveMM: Double?
    let soilMoisture: Double?
    let temperature: Double?

    var id: Date { date }
}

nonisolated struct ScheduleRecommendation: Equatable {
    let days: [DayAssessment]
    /// Hari yang disarankan, kalau ada.
    let recommended: DayAssessment?
    /// Label tambahan saat yang terbaik pun bukan hari HIJAU.
    let recommendationCaveat: String?
    /// Hari yang sebaiknya dihindari.
    let avoid: [DayAssessment]
    let allRed: Bool
}

/// Gerbang cuaca pemupukan.
///
/// STATUS DITENTUKAN CURAH HUJAN SAJA. Lengas dan suhu hanya mengubah TINDAKAN,
/// tidak pernah status — lengas tanah dari ramalan berskala ~10 km dan
/// menggambarkan tanah hamparan, bukan media di dalam polybag yang volumenya
/// kecil dan mengering jauh lebih cepat. Nilainya di Batam bertahan di
/// 0,08–0,09 m³/m³ bahkan pada hari berhujan 13 mm, jadi ambang mutlak apa pun
/// akan menandai setiap hari sama.
///
/// Lagi pula tanah kering BUKAN alasan menunda pemupukan — ia alasan menyiram
/// lebih dulu, dan itu tindakan, bukan status.
nonisolated enum FertilizerWindow {
    static let allRedMessage =
        "Semua hari dalam jendela ramalan berstatus MERAH. Memupuk di hari MERAH membuang pupuknya, bukan sekadar menundanya."
    static let bestAvailableCaveat = "terbaik yang ada (tidak ideal)"

    static func evaluate(
        forecast: HourlyForecast,
        thresholds: FertilizerThresholds,
        calendar: Calendar = .current
    ) -> ScheduleRecommendation {
        guard !forecast.isEmpty else {
            return ScheduleRecommendation(days: [], recommended: nil,
                                          recommendationCaveat: nil, avoid: [], allRed: false)
        }

        // Lengas dipakai RELATIF terhadap sebarannya sendiri di jendela ramalan.
        let moistureMedian = median(forecast.soilMoisture3to9.compactMap { $0 })

        var days: [DayAssessment] = []
        for (index, time) in forecast.times.enumerated() {
            guard calendar.component(.hour, from: time) == thresholds.applicationHour else { continue }

            let washout = sum(forecast.precipitationMM, from: index, hours: thresholds.washoutWindowHours)
            let dissolve = sum(forecast.precipitationMM, from: index, hours: thresholds.dissolveWindowHours)
            let moisture = forecast.soilMoisture3to9[safe: index] ?? nil
            let temperature = forecast.temperature2m[safe: index] ?? nil

            let (status, reason) = classify(washout: washout, dissolve: dissolve, thresholds: thresholds)
            let action = recommendAction(
                status: status,
                dissolve: dissolve,
                moisture: moisture,
                moistureMedian: moistureMedian,
                temperature: temperature,
                thresholds: thresholds
            )

            days.append(
                DayAssessment(
                    date: calendar.startOfDay(for: time),
                    status: status,
                    reason: reason,
                    action: action,
                    washoutMM: washout,
                    dissolveMM: dissolve,
                    soilMoisture: moisture,
                    temperature: temperature
                )
            )
        }

        let firstGreen = days.first(where: { $0.status == .green })
        let firstYellow = days.first(where: { $0.status == .yellow })
        let recommended = firstGreen ?? firstYellow
        let allRed = !days.isEmpty && days.allSatisfy { $0.status == .red }

        return ScheduleRecommendation(
            days: days,
            recommended: recommended,
            recommendationCaveat: firstGreen == nil && firstYellow != nil ? bestAvailableCaveat : nil,
            avoid: days.filter { $0.status == .red },
            allRed: allRed
        )
    }

    /// STATUS: curah hujan saja.
    static func classify(
        washout: Double?,
        dissolve: Double?,
        thresholds: FertilizerThresholds
    ) -> (FertilizerStatus, String) {
        guard let washout else {
            return (.yellow, "Ramalan tidak lengkap untuk hari ini — periksa langit sendiri.")
        }
        if washout >= thresholds.washoutMM {
            return (.red, "Hara akan hanyut sebelum sempat diserap (\(formatted(washout)) mm dalam \(thresholds.washoutWindowHours) jam). Tunda.")
        }
        if washout >= thresholds.approachingMM {
            return (.yellow, "Mendekati ambang pencucian (\(formatted(washout)) mm dalam \(thresholds.washoutWindowHours) jam).")
        }
        if let dissolve, dissolve >= thresholds.idealMinMM, dissolve <= thresholds.idealMaxMM {
            return (.green, "Hujan ringan menyusul (\(formatted(dissolve)) mm) — justru membantu melarutkan.")
        }
        return (.green, "Aman dari pencucian.")
    }

    /// TINDAKAN: di sinilah lengas dan suhu masuk, dan HANYA di sini.
    static func recommendAction(
        status: FertilizerStatus,
        dissolve: Double?,
        moisture: Double?,
        moistureMedian: Double?,
        temperature: Double?,
        thresholds: FertilizerThresholds
    ) -> String {
        var action: String
        if status == .yellow {
            action = "Boleh, tapi pupuk sore dan jangan berlebih; siap ulang besok."
        } else if let dissolve, dissolve >= thresholds.idealMinMM {
            action = "PUPUK HARI INI — hujan ringan akan meresapkannya sendiri."
        } else {
            action = "PUPUK SORE, lalu siram tipis agar meresap."
        }
        if let temperature, temperature >= 32 {
            action += " (siang panas — jangan pagi, urea menguap)"
        }
        if let moisture, let moistureMedian, moisture < moistureMedian {
            action += "; media polybag kemungkinan kering, periksa dengan jari."
        }
        return action
    }

    /// Jumlah dalam jendela jam. `nil` dilewati; jendela yang seluruhnya kosong
    /// menghasilkan `nil`, bukan nol — nol akan terbaca sebagai "tidak hujan".
    static func sum(_ values: [Double?], from index: Int, hours: Int) -> Double? {
        guard index >= 0, index < values.count, hours > 0 else { return nil }
        let upper = min(index + hours, values.count)
        var total = 0.0
        var found = false
        for position in index..<upper {
            guard let value = values[position] else { continue }
            total += value
            found = true
        }
        return found ? total : nil
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 1 { return sorted[middle] }
        return (sorted[middle - 1] + sorted[middle]) / 2
    }

    private static func formatted(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

private extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
