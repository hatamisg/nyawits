import CoreImage
import Foundation
import ImageIO

/// Pembaca DN dari frame RAW.
///
/// Satu-satunya berkas di subsistem ini yang menyentuh CoreImage/ImageIO.
/// Matematikanya ada di `MeasurementCalculator` yang murni; di sini hanya
/// "berapa rerata piksel di dalam kotak ini".
///
/// Dekode RAW disetel SEDATAR MUNGKIN dan SAMA untuk setiap frame: tanpa boost,
/// tanpa kurva nada, tanpa denoise, tanpa penajaman, dan dengan titik netral
/// yang dipatok tetap. Seluruh perhitungan di atasnya membandingkan kanal satu
/// terhadap yang lain, jadi pengolahan yang berbeda antar frame akan
/// mengacaknya — itulah kenapa §0 menuntut RAW dengan white balance terkunci.
@MainActor
final class RawFrameSampler {
    /// Titik netral D50, dipatok tetap. Yang penting bukan nilainya, melainkan
    /// bahwa SETIAP frame mendapat perlakuan yang persis sama.
    private static let neutralChromaticity = CGPoint(x: 0.3457, y: 0.3585)

    /// Ruang kerja LINEAR: DN harus sebanding dengan cahaya yang masuk.
    /// Ruang ber-gamma akan membuat pembagian dengan kartu tidak lagi
    /// membatalkan drift iluminasi.
    private let linearColorSpace = CGColorSpace(name: CGColorSpace.linearSRGB)
        ?? CGColorSpaceCreateDeviceRGB()

    private lazy var context = CIContext(options: [
        .workingColorSpace: linearColorSpace,
        .outputColorSpace: linearColorSpace,
        .cacheIntermediates: false
    ])

    enum SamplerError: Error, Equatable {
        case cannotDecodeRAW
        case invalidROI
        case renderFailed

        var message: String {
            switch self {
            case .cannotDecodeRAW:
                "Frame ini tidak dapat didekode sebagai RAW. Angka DN-nya tidak akan berarti, jadi perhitungan dihentikan."
            case .invalidROI:
                "Kotak ROI berada di luar frame atau tidak punya luas."
            case .renderFailed:
                "Rerata piksel ROI gagal dihitung."
            }
        }
    }

    /// Gambar untuk DITAMPILKAN saja — jangan sekali pun dipakai mengukur.
    ///
    /// Draft mode dan penyekalaan dipakai supaya pratinjau cepat, dan hasilnya
    /// dikonversi ke sRGB supaya tidak tampak gelap di layar. Keduanya membuat
    /// pikselnya tidak lagi linear, jadi angkanya tidak berarti apa-apa.
    func previewImage(at url: URL, maxPixelSize: CGFloat = 1600) -> CGImage? {
        guard let filter = CIRAWFilter(imageURL: url) else { return nil }
        filter.isDraftModeEnabled = true
        let native = max(filter.nativeSize.width, filter.nativeSize.height)
        if native > maxPixelSize, native > 0 {
            filter.scaleFactor = Float(maxPixelSize / native)
        }
        guard let image = filter.outputImage else { return nil }
        let display = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        return context.createCGImage(image, from: image.extent, format: .RGBA8, colorSpace: display)
    }

    /// Baca DN untuk seluruh band yang disumbang SATU frame.
    ///
    /// Untuk frame RGB, satu pasang kotak melayani KETIGA kanal — kanopi dan
    /// kartu hanya ditandai sekali.
    ///
    /// Untuk frame spektral, DN diambil sebagai rerata ketiga kanal linear:
    /// di balik filter IR-pass ketiga sumur Bayer melihat band yang sama, dan
    /// merata-ratakan menurunkan derau. ASUMSI yang perlu dikonfirmasi setelah
    /// frame lapangan pertama ada.
    func readings(
        frame: ImportedFrame,
        frameURL: URL,
        canopy: ROIRect,
        card: ROIRect
    ) throws -> [BandReading] {
        // Dibaca dari bidang CFA langsung, BUKAN lewat CIRAWFilter: dekode RAW
        // Apple menerapkan white balance dan ColorMatrix yang mencampur antar
        // kanal, dan pencampuran itu tidak saling meniadakan saat kanopi dibagi
        // kartu. Terukur galat 7-25 % pada kanal RGB; jalur ini di bawah 0,01 %.
        let image = try DNGRawReader.read(contentsOf: frameURL)
        guard let canopyColors = image.meanByCFAColor(in: canopy),
              let cardColors = image.meanByCFAColor(in: card),
              let canopyAll = image.meanAllPhotosites(in: canopy),
              let cardAll = image.meanAllPhotosites(in: card) else {
            throw SamplerError.invalidROI
        }

        return frame.role.bands.map { label in
            let canopyDN: Double
            let cardDN: Double
            switch label {
            case .lp720, .lp850:
                // Di balik filter IR-pass ketiga sumur Bayer melihat band yang sama.
                canopyDN = canopyAll
                cardDN = cardAll
            case .red:
                canopyDN = canopyColors.red
                cardDN = cardColors.red
            case .green:
                canopyDN = canopyColors.green
                cardDN = cardColors.green
            case .blue:
                canopyDN = canopyColors.blue
                cardDN = cardColors.blue
            }
            return BandReading(
                label: label,
                frameFilename: frame.filename,
                canopyROI: canopy,
                cardROI: card,
                canopyDN: canopyDN,
                cardDN: cardDN
            )
        }
    }
}

/// Satu-satunya implementasi `SpectralFrameSource`: pemilih berkas.
///
/// Klien jaringan Raspberry Pi sengaja tidak dibangun (§10). Kalau nanti
/// dibangun, ia mengimplementasi protokol yang sama dan tidak ada lapisan di
/// atasnya yang berubah.
@MainActor
final class FileImportFrameSource: SpectralFrameSource {
    private let store: ScanSessionStore

    let sourceName = "Berkas dari rig"

    init(store: ScanSessionStore) {
        self.store = store
    }

    func adopt(fileAt url: URL, as role: FrameRole) throws -> ImportedFrame {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            throw FrameImportError.unreadableFile
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw FrameImportError.unsupportedImage
        }

        let frameID = UUID()
        guard let filename = store.saveFrame(
            data,
            frameID: frameID,
            pathExtension: url.pathExtension
        ) else {
            throw FrameImportError.storageFailure
        }

        return ImportedFrame(
            id: frameID,
            role: role,
            filename: filename,
            sourceFormat: url.pathExtension.lowercased(),
            isRaw: Self.isRAW(source),
            asShotNeutral: Self.asShotNeutral(source)
        )
    }

    /// RAW dikenali dari tipe berkasnya, bukan dari ekstensinya: berkas JPEG
    /// yang dinamai .dng tidak boleh lolos sebagai RAW.
    private static func isRAW(_ source: CGImageSource) -> Bool {
        guard let type = CGImageSourceGetType(source) as String? else { return false }
        let lowered = type.lowercased()
        if lowered.contains("raw") { return true }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [CFString: Any] else { return false }
        return properties[kCGImagePropertyDNGDictionary] != nil
    }

    /// `AsShotNeutral` DNG: pengali per kanal yang dipilih kamera saat memotret.
    /// Nilai yang berbeda antar frame satu petak berarti WB tidak terkunci.
    private static func asShotNeutral(_ source: CGImageSource) -> [Double]? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [CFString: Any],
              let dng = properties[kCGImagePropertyDNGDictionary] as? [CFString: Any],
              let neutral = dng[kCGImagePropertyDNGAsShotNeutral] as? [NSNumber] else {
            return nil
        }
        return neutral.map(\.doubleValue)
    }
}
