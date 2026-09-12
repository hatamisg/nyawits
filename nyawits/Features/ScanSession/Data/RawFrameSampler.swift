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

    /// Rerata DN satu kotak, per kanal linear.
    /// Mengembalikan (r, g, b) dalam ruang linear.
    ///
    /// Sengaja tidak `private`: pembalikan sumbu Y di bawah adalah tempat paling
    /// mudah tertukarnya ROI kanopi dan ROI kartu tanpa gejala yang terlihat,
    /// jadi ia diuji langsung.
    func averageChannels(of image: CIImage, roi: ROIRect) throws -> (Double, Double, Double) {
        guard roi.isValid else { throw SamplerError.invalidROI }
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { throw SamplerError.invalidROI }

        // ROI memakai origin kiri-ATAS (konvensi UI); CIImage memakai kiri-BAWAH.
        let width = roi.width * extent.width
        let height = roi.height * extent.height
        let x = extent.origin.x + roi.x * extent.width
        let y = extent.origin.y + (1.0 - roi.y - roi.height) * extent.height
        let rect = CGRect(x: x, y: y, width: width, height: height)
        guard rect.width >= 1, rect.height >= 1 else { throw SamplerError.invalidROI }

        let averaged = image.applyingFilter("CIAreaAverage", parameters: [
            kCIInputExtentKey: CIVector(cgRect: rect)
        ])

        var pixel = [Float](repeating: 0, count: 4)
        context.render(
            averaged,
            toBitmap: &pixel,
            rowBytes: MemoryLayout<Float>.size * 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBAf,
            colorSpace: linearColorSpace
        )
        guard pixel.allSatisfy({ $0.isFinite }) else { throw SamplerError.renderFailed }
        return (Double(pixel[0]), Double(pixel[1]), Double(pixel[2]))
    }

    /// Dekode RAW dengan pengolahan dimatikan sejauh yang bisa dimatikan.
    private func linearImage(at url: URL) throws -> CIImage {
        guard let filter = CIRAWFilter(imageURL: url) else {
            throw SamplerError.cannotDecodeRAW
        }
        filter.isGamutMappingEnabled = false
        filter.isDraftModeEnabled = false
        filter.exposure = 0
        filter.baselineExposure = 0
        filter.shadowBias = 0
        filter.boostAmount = 0
        filter.boostShadowAmount = 0
        filter.extendedDynamicRangeAmount = 0
        // Beberapa knob hanya ada kalau dekoder mendukungnya untuk sensor ini.
        if filter.isContrastSupported { filter.contrastAmount = 0 }
        if filter.isDetailSupported { filter.detailAmount = 0 }
        if filter.isSharpnessSupported { filter.sharpnessAmount = 0 }
        if filter.isLuminanceNoiseReductionSupported { filter.luminanceNoiseReductionAmount = 0 }
        if filter.isColorNoiseReductionSupported { filter.colorNoiseReductionAmount = 0 }
        if filter.isMoireReductionSupported { filter.moireReductionAmount = 0 }
        if filter.isLocalToneMapSupported { filter.localToneMapAmount = 0 }
        if filter.isLensCorrectionSupported { filter.isLensCorrectionEnabled = false }
        // Titik netral dipatok: penguatan per kanal harus sama di semua frame.
        // Inilah yang membuat perbandingan antar kanal tetap sah — dan kenapa
        // frame non-RAW (yang sudah kena auto white balance) ditolak lebih dulu.
        filter.neutralChromaticity = Self.neutralChromaticity

        guard let image = filter.outputImage else { throw SamplerError.cannotDecodeRAW }
        return image
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
        let image = try linearImage(at: frameURL)
        let canopyChannels = try averageChannels(of: image, roi: canopy)
        let cardChannels = try averageChannels(of: image, roi: card)

        return frame.role.bands.map { label in
            let canopyDN: Double
            let cardDN: Double
            switch label {
            case .lp720, .lp850:
                canopyDN = (canopyChannels.0 + canopyChannels.1 + canopyChannels.2) / 3
                cardDN = (cardChannels.0 + cardChannels.1 + cardChannels.2) / 3
            case .red:
                canopyDN = canopyChannels.0
                cardDN = cardChannels.0
            case .green:
                canopyDN = canopyChannels.1
                cardDN = cardChannels.1
            case .blue:
                canopyDN = canopyChannels.2
                cardDN = cardChannels.2
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
