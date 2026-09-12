import Foundation

/// Label satu entri band. Tiga frame menghasilkan LIMA entri: frame RGB
/// menyumbang tiga kanal yang berbagi berkas frame dan ROI yang sama.
///
/// Raw value dipakai apa adanya sebagai kunci JSON, jadi jangan diubah tanpa
/// memikirkan data yang sudah ada di perangkat.
nonisolated enum BandLabel: String, Codable, CaseIterable, Identifiable {
    case lp720
    case lp850
    case red = "R"
    case green = "G"
    case blue = "B"

    var id: Self { self }

    /// Frame fisik asal entri ini. Ketiga kanal RGB berbagi satu frame.
    var frame: FrameRole {
        switch self {
        case .lp720: .spectralLow
        case .lp850: .spectralHigh
        case .red, .green, .blue: .rgb
        }
    }

    var title: String {
        switch self {
        case .lp720: "IR-pass 720 nm"
        case .lp850: "IR-pass 850 nm"
        case .red: "Kanal merah"
        case .green: "Kanal hijau"
        case .blue: "Kanal biru"
        }
    }
}

/// Peran satu frame di dalam satu petak. Tiga frame per petak.
nonisolated enum FrameRole: String, Codable, CaseIterable, Identifiable {
    case spectralLow
    case spectralHigh
    case rgb

    var id: Self { self }

    var title: String {
        switch self {
        case .spectralLow: "Frame spektral 720 nm"
        case .spectralHigh: "Frame spektral 850 nm"
        case .rgb: "Frame RGB"
        }
    }

    /// Entri band yang disumbang frame ini.
    var bands: [BandLabel] {
        switch self {
        case .spectralLow: [.lp720]
        case .spectralHigh: [.lp850]
        case .rgb: [.red, .green, .blue]
        }
    }
}

/// Kotak ROI dalam FRAKSI ukuran frame (0…1), bukan piksel: frame boleh
/// berganti resolusi tanpa membuat koordinat lama salah arti.
nonisolated struct ROIRect: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Kotak harus punya luas dan berada di dalam frame.
    var isValid: Bool {
        guard x.isFinite, y.isFinite, width.isFinite, height.isFinite else { return false }
        guard width > 0, height > 0 else { return false }
        return x >= 0 && y >= 0 && x + width <= 1.0001 && y + height <= 1.0001
    }
}

/// Satu entri band: dua DN mentah plus asal-usulnya.
///
/// DN disimpan mentah dan TIDAK PERNAH diganti hasil olahannya. Koefisien dan
/// bahkan definisi fitur masih mungkin berubah — sudah berubah dari dua menjadi
/// lima — jadi sesi lama harus tetap bisa dihitung ulang.
nonisolated struct BandReading: Codable, Equatable, Identifiable {
    let id: UUID
    let label: BandLabel
    /// Nama berkas saja, bukan path absolut: path container berubah tiap install.
    let frameFilename: String
    let canopyROI: ROIRect
    let cardROI: ROIRect
    /// Rerata DN ROI kanopi, mentah.
    let canopyDN: Double
    /// Rerata DN ROI kartu abu-abu di FRAME YANG SAMA, mentah.
    let cardDN: Double

    init(
        id: UUID = UUID(),
        label: BandLabel,
        frameFilename: String,
        canopyROI: ROIRect,
        cardROI: ROIRect,
        canopyDN: Double,
        cardDN: Double
    ) {
        self.id = id
        self.label = label
        self.frameFilename = frameFilename
        self.canopyROI = canopyROI
        self.cardROI = cardROI
        self.canopyDN = canopyDN
        self.cardDN = cardDN
    }
}

/// Satu petak = satu tanaman. Isinya DAFTAR band, bukan lima field bernama:
/// kalau konfigurasi optiknya berubah lagi, jumlah entri berubah dan skema
/// tidak perlu dibongkar.
nonisolated struct PlantMeasurement: Codable, Equatable, Identifiable {
    let id: UUID
    let recordedAt: Date
    var bands: [BandReading]
    // Optional additions keep existing on-device JSON readable.
    /// Tautan ke PlantObservation kalau tanamannya sudah pernah difoto ARKit.
    var plantObservationID: UUID? = nil
    /// Tautan cadangan kalau belum: ketiganya sudah ada di PlantObservation dan stabil.
    var rowID: UUID? = nil
    var rowNumber: Int? = nil
    var side: PlantCaptureSide? = nil
    var plantSequence: Int? = nil
    /// Nama petak yang diketik petani kalau tidak ditautkan ke tanaman mana pun.
    var label: String? = nil
    /// Kering? Ternaungi? Baru disiram? Alat ini tidak bisa menyebut penyebab
    /// ketertinggalan, dan catatan ini satu-satunya tempat penyebabnya terekam.
    var fieldNote: String? = nil
    /// Format berkas frame apa adanya, untuk audit premis RAW.
    var rawFormat: String? = nil
    /// Nil berarti belum diketahui, bukan berarti terkunci.
    var whiteBalanceLocked: Bool? = nil

    init(
        id: UUID = UUID(),
        recordedAt: Date = Date(),
        bands: [BandReading]
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.bands = bands
    }

    func band(_ label: BandLabel) -> BandReading? {
        bands.first(where: { $0.label == label })
    }
}

/// Satu kebun-epoch: unit normalisasi p90.
///
/// BUKAN `captureSessionID` milik ARKit — yang itu diundi ulang tiap kamera
/// dijalankan, jadi memakainya sebagai unit p90 akan memecah satu sesi lapangan
/// menjadi beberapa dan menormalisasi tiap pecahan sendiri-sendiri.
///
/// Sesi dibuka dan ditutup SECARA EKSPLISIT oleh pengguna. Sebelum ditutup,
/// petak belum punya skor: p90 belum ada.
nonisolated struct ScanSession: Codable, Equatable, Identifiable {
    let id: UUID
    let fieldID: UUID
    let openedAt: Date
    var measurements: [PlantMeasurement]
    // Optional additions keep existing on-device JSON readable.
    var closedAt: Date? = nil
    var label: String? = nil
    /// Catatan lapangan tingkat sesi (cuaca, kejadian) di luar catatan per petak.
    var note: String? = nil

    init(
        id: UUID = UUID(),
        fieldID: UUID,
        openedAt: Date = Date(),
        measurements: [PlantMeasurement] = []
    ) {
        self.id = id
        self.fieldID = fieldID
        self.openedAt = openedAt
        self.measurements = measurements
    }

    var isClosed: Bool { closedAt != nil }

    var measurementCount: Int { measurements.count }

    /// Jumlah petak yang disarankan sebelum sesi ditutup. Di bawah ini p90
    /// kehilangan arti — pada n = 2 ia praktis nilai maksimum. Angkanya
    /// PENILAIAN, bukan hasil sapuan, jadi ia memperingatkan dan tidak menolak.
    static let suggestedMinimumMeasurements = 6
}
