import Foundation

/// Kelima fitur skor. Raw value HARUS sama dengan isi array `fitur` di
/// `vigor_rank_rgb.json`, karena pemetaan koefisien dilakukan lewat nama kunci.
nonisolated enum VigorFeature: String, Codable, CaseIterable, Identifiable, Sendable {
    case siRel = "SI_rel"
    case bHiRel = "b_hi_rel"
    case bRRel = "b_R_rel"
    case bGRel = "b_G_rel"
    case bBRel = "b_B_rel"

    var id: Self { self }
}

nonisolated enum VigorModelError: Error, Equatable {
    case malformedJSON
    case emptyFeatureList
    case unknownFeature(String)
    case duplicateFeature(String)
    case missingCoefficient(String)
    case nonFiniteCoefficient(String)
    case nonFiniteIntercept
    case missingFeatureValue(VigorFeature)

    /// Pesan berbahasa Indonesia. Semuanya berakhir sama: perhitungan dihentikan,
    /// karena memakai angka lama diam-diam jauh lebih berbahaya daripada gagal.
    var message: String {
        switch self {
        case .malformedJSON:
            "Berkas model vigor tidak dapat dibaca. Perhitungan skor dihentikan."
        case .emptyFeatureList:
            "Berkas model vigor tidak memuat satu pun fitur. Perhitungan skor dihentikan."
        case let .unknownFeature(name):
            "Berkas model vigor memuat fitur yang tidak dikenali aplikasi (\(name)). Perhitungan skor dihentikan."
        case let .duplicateFeature(name):
            "Berkas model vigor memuat fitur ganda (\(name)). Perhitungan skor dihentikan."
        case let .missingCoefficient(name):
            "Koefisien untuk fitur \(name) tidak ada di berkas model. Perhitungan skor dihentikan."
        case let .nonFiniteCoefficient(name):
            "Koefisien untuk fitur \(name) bukan bilangan yang sah. Perhitungan skor dihentikan."
        case .nonFiniteIntercept:
            "Intercept model bukan bilangan yang sah. Perhitungan skor dihentikan."
        case let .missingFeatureValue(feature):
            "Nilai \(feature.rawValue) belum tersedia untuk petak ini. Perhitungan skor dihentikan."
        }
    }
}

/// Pembaca `vigor_rank_rgb.json`.
///
/// TIDAK ADA satu pun koefisien yang ditulis sebagai literal Swift — tidak
/// sebagai nilai default, tidak sebagai fallback kalau JSON gagal dibaca, dan
/// tidak di komentar yang bisa tersalin. Nilainya sudah berubah dua kali dan
/// jumlah fiturnya sekali; kalibrasi ulang tidak boleh menuntut kompilasi ulang.
///
/// Berkas yang dibaca `vigor_rank_rgb.json`, BUKAN `vigor_rank.json` — yang
/// kedua adalah model dua fitur yang dipertahankan untuk riwayat dan tidak
/// boleh dipakai aplikasi.
nonisolated struct VigorModel: Equatable {
    static let resourceName = "vigor_rank_rgb"
    static let resourceSubdirectory = "Model"

    /// Urutan persis seperti array `fitur` di JSON. Skor dijumlahkan mengikuti
    /// urutan ini, tapi nilainya dicari lewat nama — posisi tidak menentukan apa pun.
    let features: [VigorFeature]
    let coefficients: [VigorFeature: Double]
    let intercept: Double
    /// Dibaca apa adanya dari JSON dan ditampilkan apa adanya di layar hasil,
    /// supaya kalibrasi ulang yang mengubah peringatannya langsung terbawa.
    let warnings: [String]
    /// `null` di JSON berarti belum divalidasi — dan itu disengaja.
    let fieldValidation: String?
    let featureSetLabel: String?
    let configuration: String?
    let outputDescription: String?
    let trainingJitter: Double?

    /// Kalau UI menampilkan status validasi, ia harus menampilkan bahwa slotnya
    /// kosong, bukan menyembunyikannya.
    var fieldValidationText: String {
        fieldValidation ?? "belum divalidasi di lapangan"
    }

    // MARK: - Pembacaan

    private struct Payload: Decodable {
        let fitur: [String]
        let koefisien: [String: Double]
        let intercept: Double
        let peringatan: [String]?
        let validasiLapangan: String?
        let himpunanFitur: String?
        let konfigurasi: String?
        let keluaran: String?
        let goyanganSaatDilatih: Double?

        enum CodingKeys: String, CodingKey {
            case fitur
            case koefisien
            case intercept
            case peringatan
            case validasiLapangan = "validasi_lapangan"
            case himpunanFitur = "himpunan_fitur"
            case konfigurasi
            case keluaran
            case goyanganSaatDilatih = "goyangan_saat_dilatih"
        }
    }

    static func load(data: Data) throws -> VigorModel {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            throw VigorModelError.malformedJSON
        }
        guard !payload.fitur.isEmpty else { throw VigorModelError.emptyFeatureList }

        var features: [VigorFeature] = []
        var coefficients: [VigorFeature: Double] = [:]

        // Urutan ditentukan array `fitur`; koefisien dicari LEWAT NAMA KUNCI.
        // Kalau model dilatih ulang dengan urutan berbeda, kode ini tetap benar.
        for name in payload.fitur {
            guard let feature = VigorFeature(rawValue: name) else {
                throw VigorModelError.unknownFeature(name)
            }
            guard !features.contains(feature) else {
                throw VigorModelError.duplicateFeature(name)
            }
            guard let coefficient = payload.koefisien[name] else {
                throw VigorModelError.missingCoefficient(name)
            }
            guard coefficient.isFinite else {
                throw VigorModelError.nonFiniteCoefficient(name)
            }
            features.append(feature)
            coefficients[feature] = coefficient
        }
        guard payload.intercept.isFinite else { throw VigorModelError.nonFiniteIntercept }

        return VigorModel(
            features: features,
            coefficients: coefficients,
            intercept: payload.intercept,
            warnings: payload.peringatan ?? [],
            fieldValidation: payload.validasiLapangan,
            featureSetLabel: payload.himpunanFitur,
            configuration: payload.konfigurasi,
            outputDescription: payload.keluaran,
            trainingJitter: payload.goyanganSaatDilatih
        )
    }

    static func loadFromBundle(_ bundle: Bundle = .main) throws -> VigorModel {
        let data = try BundleJSONResource.data(
            named: resourceName,
            subdirectory: resourceSubdirectory,
            bundle: bundle
        )
        return try load(data: data)
    }

    // MARK: - Skor

    /// Skor = jumlah koefisien × nilai relatif, ditambah intercept.
    ///
    /// NILAI RENDAH = PALING TERTINGGAL. Model memprediksi vigor, dan vigor
    /// rendah sudah berarti tertinggal — JANGAN dinegasikan. Menegasikannya
    /// membalik peringkat sepenuhnya (rho −0,89), dan itu sudah pernah terjadi.
    func score(relative values: [VigorFeature: Double]) throws -> Double {
        var total = intercept
        for feature in features {
            guard let value = values[feature], value.isFinite else {
                throw VigorModelError.missingFeatureValue(feature)
            }
            guard let coefficient = coefficients[feature] else {
                throw VigorModelError.missingCoefficient(feature.rawValue)
            }
            total += coefficient * value
        }
        return total
    }
}
