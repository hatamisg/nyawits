import Foundation

/// Besaran satu petak yang bisa dihitung MANDIRI, segera setelah dipotret.
/// Semua yang di bawah ini menunggu petak terakhir — lihat penghalang p90.
nonisolated struct MeasurementQuantities: Equatable {
    let measurementID: UUID
    /// b = DN kanopi / DN kartu, di dalam FRAME-nya sendiri.
    let bLo: Double
    let bHi: Double
    let bR: Double
    let bG: Double
    let bB: Double
    /// Kemiringan red edge. SELALU positif: reflektansi kanopi naik melalui
    /// red edge, jadi b_hi > b_lo.
    let si: Double
}

nonisolated enum MeasurementRejection: Error, Equatable {
    case missingBand(BandLabel)
    case invalidCardDN(BandLabel)
    case invalidCanopyDN(BandLabel)

    var message: String {
        switch self {
        case let .missingBand(label):
            "Band \(label.rawValue) belum diukur. Kartu abu-abu wajib ada di ketiga frame; petak ini tidak bisa dihitung."
        case let .invalidCardDN(label):
            "DN kartu abu-abu pada band \(label.rawValue) tidak sah. Petak ini tidak bisa dinormalisasi."
        case let .invalidCanopyDN(label):
            "DN kanopi pada band \(label.rawValue) tidak sah. Petak ini tidak bisa dihitung."
        }
    }
}

nonisolated struct ExcludedMeasurement: Equatable, Identifiable {
    let measurementID: UUID
    let reason: MeasurementRejection
    var id: UUID { measurementID }
}

nonisolated enum RankingWarning: Equatable {
    /// p90 kehilangan arti kalau petaknya terlalu sedikit — pada n = 2 ia
    /// praktis nilai maksimum. Ini PERINGATAN, bukan penolakan: angka
    /// minimumnya penilaian, bukan hasil sapuan.
    case tooFewMeasurements(count: Int, suggested: Int)
    /// SI mestinya selalu positif. Negatif berarti ada yang terbalik — paling
    /// sering filter 720 dan 850 tertukar saat impor.
    case nonPositiveSlope(measurementIDs: [UUID])
    case someMeasurementsExcluded(count: Int)

    var message: String {
        switch self {
        case let .tooFewMeasurements(count, suggested):
            "Sesi ini baru berisi \(count) petak. Pembanding p90 baru bermakna mulai sekitar \(suggested) petak; peringkat di bawah itu rapuh."
        case let .nonPositiveSlope(ids):
            "\(ids.count) petak punya kemiringan red edge nol atau negatif. Itu tidak wajar — periksa apakah frame 720 dan 850 tertukar saat diimpor."
        case let .someMeasurementsExcluded(count):
            "\(count) petak dikeluarkan dari peringkat karena pengukurannya belum lengkap."
        }
    }
}

nonisolated enum RankingError: Error, Equatable {
    case sessionNotClosed
    case noUsableMeasurements
    case invalidDivisor(VigorFeature)

    var message: String {
        switch self {
        case .sessionNotClosed:
            "Sesi belum ditutup, jadi pembanding p90 belum ada. Peringkat baru bisa dihitung setelah sesi ditutup."
        case .noUsableMeasurements:
            "Belum ada petak yang lengkap untuk dihitung. Peringkat tidak dapat disusun."
        case let .invalidDivisor(feature):
            "Persentil-90 untuk \(feature.rawValue) nol atau tidak sah, jadi normalisasi tidak mungkin dilakukan."
        }
    }
}

nonisolated struct ScoredMeasurement: Equatable, Identifiable {
    let measurementID: UUID
    let quantities: MeasurementQuantities
    /// Kelima nilai relatif, masing-masing dibagi p90-NYA SENDIRI.
    let relative: [VigorFeature: Double]
    /// Nilai rendah = paling tertinggal.
    let score: Double
    /// 1 = prioritas kunjungan pertama.
    let visitPriority: Int

    var id: UUID { measurementID }
}

/// Peringkat satu sesi.
///
/// Peringkat adalah properti SESI, bukan properti foto. Membandingkan skor
/// antar sesi atau antar kebun TIDAK SAH — pembandingnya (p90) berbeda.
nonisolated struct SessionRanking: Equatable {
    let sessionID: UUID
    /// Urut naik: elemen pertama adalah kunjungan pertama.
    let scored: [ScoredMeasurement]
    /// p90 tiap besaran, disimpan supaya angkanya bisa diaudit.
    let divisors: [VigorFeature: Double]
    let excluded: [ExcludedMeasurement]
    let warnings: [RankingWarning]
}

/// Seluruh matematika pipeline. Murni: hanya `Foundation`, tanpa SwiftUI,
/// ARKit, atau UIKit, supaya bisa dikompilasi dan diuji dengan `swiftc`.
nonisolated enum MeasurementCalculator {

    // MARK: - Per petak, mandiri

    /// Kelima b, lalu SI. Urutan ini TIDAK BOLEH DIBALIK: normalisasi dulu
    /// (bagi dengan kartu), kurangkan belakangan. Urutan sebaliknya —
    /// `(s_lo - s_hi) / (c_lo - c_hi)` — didominasi struktur kanopi alih-alih
    /// pigmen (korelasi parsial −0,107 versus +0,435, terbalik).
    static func quantities(for measurement: PlantMeasurement) -> Result<MeasurementQuantities, MeasurementRejection> {
        var normalized: [BandLabel: Double] = [:]

        for label in BandLabel.allCases {
            guard let reading = measurement.band(label) else {
                return .failure(.missingBand(label))
            }
            guard reading.cardDN.isFinite, reading.cardDN > 0 else {
                return .failure(.invalidCardDN(label))
            }
            guard reading.canopyDN.isFinite, reading.canopyDN >= 0 else {
                return .failure(.invalidCanopyDN(label))
            }
            normalized[label] = reading.canopyDN / reading.cardDN
        }

        guard let bLo = normalized[.lp720],
              let bHi = normalized[.lp850],
              let bR = normalized[.red],
              let bG = normalized[.green],
              let bB = normalized[.blue] else {
            return .failure(.missingBand(.lp720))
        }

        return .success(
            MeasurementQuantities(
                measurementID: measurement.id,
                bLo: bLo,
                bHi: bHi,
                bR: bR,
                bG: bG,
                bB: bB,
                // SI = b_hi − b_lo, positif. Bukan b_lo − b_hi: yang itu selalu
                // negatif, dan membagi besaran negatif dengan p90-nya membuat
                // pembandingnya lot TERLEMAH — kebalikan penuh dari yang dimaksud.
                si: bHi - bLo
            )
        )
    }

    /// Besaran dasar sebelum dinormalisasi, per fitur.
    ///
    /// `b_lo` sengaja TIDAK ada di sini: ia diuji sebagai fitur keenam dan
    /// memberi +0,0 % ketepatan. Ia tetap disimpan sebagai DN mentah, tapi
    /// tidak masuk skor.
    static func baseValue(_ feature: VigorFeature, of quantities: MeasurementQuantities) -> Double {
        switch feature {
        case .siRel: quantities.si
        case .bHiRel: quantities.bHi
        case .bRRel: quantities.bR
        case .bGRel: quantities.bG
        case .bBRel: quantities.bB
        }
    }

    // MARK: - Penghalang sesi

    /// Persentil-90 dengan INTERPOLASI LINEAR, sama seperti `numpy.percentile`
    /// default. Diimplementasi sebagai "ambil elemen ke-90 %" hasilnya berbeda
    /// dan seluruh skor bergeser.
    static func percentile90(_ values: [Double]) -> Double? {
        guard !values.isEmpty, values.allSatisfy(\.isFinite) else { return nil }
        let sorted = values.sorted()
        let n = sorted.count
        let pos = 0.9 * Double(n - 1)
        let i = Int(pos.rounded(.down))
        let frac = pos - Double(i)
        guard i + 1 < n else { return sorted[i] }
        return sorted[i] + frac * (sorted[i + 1] - sorted[i])
    }

    // MARK: - Peringkat sesi

    /// Hitung peringkat seluruh sesi.
    ///
    /// Tiap besaran dinormalisasi dengan PEMBAGI p90-NYA SENDIRI, lalu diberi
    /// skor lima suku. Hasilnya urut naik: skor terkecil = kunjungan pertama.
    ///
    /// `requireClosedSession` ada supaya pemanggil tidak bisa tidak sengaja
    /// memunculkan skor sebelum sesi ditutup. Pratinjau internal boleh
    /// mematikannya; UI tidak.
    static func rank(
        session: ScanSession,
        model: VigorModel,
        requireClosedSession: Bool = true
    ) throws -> SessionRanking {
        if requireClosedSession, !session.isClosed {
            throw RankingError.sessionNotClosed
        }

        var usable: [MeasurementQuantities] = []
        var excluded: [ExcludedMeasurement] = []

        for measurement in session.measurements {
            switch quantities(for: measurement) {
            case let .success(value):
                usable.append(value)
            case let .failure(reason):
                excluded.append(ExcludedMeasurement(measurementID: measurement.id, reason: reason))
            }
        }

        guard !usable.isEmpty else { throw RankingError.noUsableMeasurements }

        // Satu pembagi p90 per besaran, dihitung atas SELURUH petak sesi ini.
        var divisors: [VigorFeature: Double] = [:]
        for feature in model.features {
            let values = usable.map { baseValue(feature, of: $0) }
            guard let divisor = percentile90(values), divisor.isFinite, divisor != 0 else {
                throw RankingError.invalidDivisor(feature)
            }
            divisors[feature] = divisor
        }

        var scored: [ScoredMeasurement] = []
        for quantity in usable {
            var relative: [VigorFeature: Double] = [:]
            for feature in model.features {
                guard let divisor = divisors[feature] else {
                    throw RankingError.invalidDivisor(feature)
                }
                relative[feature] = baseValue(feature, of: quantity) / divisor
            }
            let score = try model.score(relative: relative)
            scored.append(
                ScoredMeasurement(
                    measurementID: quantity.measurementID,
                    quantities: quantity,
                    relative: relative,
                    score: score,
                    visitPriority: 0
                )
            )
        }

        // Urut naik, tie-break ID stabil supaya urutan tidak berubah acak.
        scored.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            return lhs.measurementID.uuidString < rhs.measurementID.uuidString
        }
        let ordered = scored.enumerated().map { index, item in
            ScoredMeasurement(
                measurementID: item.measurementID,
                quantities: item.quantities,
                relative: item.relative,
                score: item.score,
                visitPriority: index + 1
            )
        }

        var warnings: [RankingWarning] = []
        if usable.count < ScanSession.suggestedMinimumMeasurements {
            warnings.append(
                .tooFewMeasurements(
                    count: usable.count,
                    suggested: ScanSession.suggestedMinimumMeasurements
                )
            )
        }
        let flatSlopes = usable.filter { $0.si <= 0 }.map(\.measurementID)
        if !flatSlopes.isEmpty {
            warnings.append(.nonPositiveSlope(measurementIDs: flatSlopes))
        }
        if !excluded.isEmpty {
            warnings.append(.someMeasurementsExcluded(count: excluded.count))
        }

        return SessionRanking(
            sessionID: session.id,
            scored: ordered,
            divisors: divisors,
            excluded: excluded,
            warnings: warnings
        )
    }
}
