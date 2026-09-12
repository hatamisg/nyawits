import Foundation

/// Satu frame yang sudah diadopsi ke penyimpanan aplikasi.
///
/// Frame mentah TIDAK PERNAH dibuang: koefisien dan definisi fitur masih
/// mungkin berubah, dan tanpa frame aslinya ROI tidak bisa diukur ulang.
/// Sesi jarang — dua kali per musim — jadi ini tidak membebani penyimpanan.
nonisolated struct ImportedFrame: Equatable, Identifiable {
    let id: UUID
    let role: FrameRole
    /// Nama berkas di `ScanFrames/`, bukan path absolut.
    let filename: String
    /// Ekstensi berkas asal apa adanya, untuk audit.
    let sourceFormat: String
    /// True hanya kalau ImageIO benar-benar mengenalinya sebagai RAW.
    let isRaw: Bool
    /// `AsShotNeutral` dari metadata DNG. Dipakai membandingkan ketiga frame
    /// satu petak: nilai yang BERBEDA adalah bukti white balance TIDAK terkunci.
    let asShotNeutral: [Double]?
}

/// Hasil pemeriksaan premis §0: frame RGB wajib RAW dengan white balance dan
/// eksposur terkunci. Ini PRASYARAT perhitungan, bukan saran kualitas.
nonisolated enum FramePremiseIssue: Equatable {
    case notRaw(role: FrameRole, format: String)
    case whiteBalanceVaries
    case whiteBalanceUnknown

    var message: String {
        switch self {
        case let .notRaw(role, format):
            "\(role.title) diimpor sebagai .\(format), bukan RAW. Seluruh keunggulan konfigurasi ini berdiri di atas perbandingan antar kanal, dan auto white balance mengacaknya. Petak ini tidak dihitung."
        case .whiteBalanceVaries:
            "Ketiga frame punya white balance yang berbeda, jadi penguatan per kanal tidak sama antar jepretan. Perbandingan antar kanal menjadi tidak sah."
        case .whiteBalanceUnknown:
            "White balance frame tidak dapat dibaca dari metadata, jadi belum bisa dipastikan terkunci. Periksa setelan rig."
        }
    }

    /// Dua yang pertama memblokir perhitungan; yang ketiga hanya memperingatkan.
    var blocksCalculation: Bool {
        switch self {
        case .notRaw, .whiteBalanceVaries: true
        case .whiteBalanceUnknown: false
        }
    }
}

nonisolated enum FramePremise {
    /// Periksa ketiga frame satu petak sekaligus: white balance hanya bisa
    /// dinilai dengan membandingkan frame satu terhadap yang lain.
    static func issues(for frames: [ImportedFrame]) -> [FramePremiseIssue] {
        var issues: [FramePremiseIssue] = frames
            .filter { !$0.isRaw }
            .map { .notRaw(role: $0.role, format: $0.sourceFormat) }

        let neutrals = frames.compactMap(\.asShotNeutral)
        if neutrals.count != frames.count {
            issues.append(.whiteBalanceUnknown)
        } else if let first = neutrals.first,
                  neutrals.contains(where: { !isClose($0, first) }) {
            issues.append(.whiteBalanceVaries)
        }
        return issues
    }

    private static func isClose(_ lhs: [Double], _ rhs: [Double]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { abs($0 - $1) <= 1e-4 }
    }
}

nonisolated enum FrameImportError: Error, Equatable {
    case unreadableFile
    case unsupportedImage
    case storageFailure

    var message: String {
        switch self {
        case .unreadableFile:
            "Berkas frame tidak dapat dibuka. Periksa apakah berkasnya masih ada."
        case .unsupportedImage:
            "Berkas ini bukan gambar yang dikenali. Pilih frame dari rig."
        case .storageFailure:
            "Frame tidak dapat disalin ke penyimpanan aplikasi."
        }
    }
}

/// Dari mana tiga frame satu petak datang.
///
/// Hanya ada SATU implementasi: pemilih berkas. Jembatan jaringan ke Raspberry
/// Pi sengaja di luar lingkup — protokolnya disediakan, klienya tidak.
@MainActor
protocol SpectralFrameSource {
    /// Nama sumber untuk ditampilkan di UI.
    var sourceName: String { get }
    /// Salin satu berkas ke penyimpanan aplikasi dan baca metadatanya.
    func adopt(fileAt url: URL, as role: FrameRole) throws -> ImportedFrame
}
