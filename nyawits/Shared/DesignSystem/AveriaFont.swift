import SwiftUI
import CoreText

/// Helper untuk mendaftarkan dan menggunakan font Averia_Serif_Libre
public enum AveriaFont {
    public static let boldName = "AveriaSerifLibre-Bold"
    public static let regularName = "AveriaSerifLibre-Regular"
    public static let lightName = "AveriaSerifLibre-Light"
    public static let italicName = "AveriaSerifLibre-Italic"
    public static let boldItalicName = "AveriaSerifLibre-BoldItalic"
    public static let lightItalicName = "AveriaSerifLibre-LightItalic"

    private static var isRegistered = false

    /// Mendaftarkan seluruh file font Averia Serif Libre ke CoreText secara rekursif dari bundle aplikasi
    public static func registerFonts() {
        guard !isRegistered else { return }
        isRegistered = true

        let fileManager = FileManager.default
        let bundleURL = Bundle.main.bundleURL

        if let enumerator = fileManager.enumerator(at: bundleURL, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                if url.pathExtension.lowercased() == "ttf" && url.lastPathComponent.contains("Averia") {
                    var error: Unmanaged<CFError>?
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
                }
            }
        }
    }

    /// Font Averia Serif Libre Bold dengan ukuran yang dapat disesuaikan dan mendukung Dynamic Type
    public static func bold(size: CGFloat, relativeTo textStyle: Font.TextStyle = .headline) -> Font {
        registerFonts()
        if UIFont(name: boldName, size: size) != nil {
            return .custom(boldName, size: size, relativeTo: textStyle)
        }
        return .system(size: size, weight: .bold, design: .serif)
    }

    /// Font Averia Serif Libre Regular dengan ukuran yang dapat disesuaikan
    public static func regular(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        registerFonts()
        if UIFont(name: regularName, size: size) != nil {
            return .custom(regularName, size: size, relativeTo: textStyle)
        }
        return .system(size: size, weight: .regular, design: .serif)
    }

    /// Font Averia Serif Libre Light dengan ukuran yang dapat disesuaikan
    public static func light(size: CGFloat, relativeTo textStyle: Font.TextStyle = .subheadline) -> Font {
        registerFonts()
        if UIFont(name: lightName, size: size) != nil {
            return .custom(lightName, size: size, relativeTo: textStyle)
        }
        return .system(size: size, weight: .light, design: .serif)
    }
}

// MARK: - Environment & View Modifiers untuk Kustomisasi Ukuran Font Judul Krops

private struct KropsTitleFontSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 22
}

private struct KropsTitleTextKey: EnvironmentKey {
    static let defaultValue: String = "krops"
}

extension EnvironmentValues {
    /// Ukuran font judul Krops di Home
    public var kropsTitleFontSize: CGFloat {
        get { self[KropsTitleFontSizeKey.self] }
        set { self[KropsTitleFontSizeKey.self] = newValue }
    }

    /// Teks judul Krops di Home (default: "krops")
    public var kropsTitleText: String {
        get { self[KropsTitleTextKey.self] }
        set { self[KropsTitleTextKey.self] = newValue }
    }
}

extension View {
    /// Menyesuaikan ukuran font tulisan krops di Home
    public func kropsTitleFontSize(_ size: CGFloat) -> some View {
        environment(\.kropsTitleFontSize, size)
    }

    /// Menyesuaikan teks judul krops di Home
    public func kropsTitleText(_ text: String) -> some View {
        environment(\.kropsTitleText, text)
    }
}
