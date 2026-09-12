import SwiftUI

/// Tangga warna posisi vigor RELATIF.
///
/// Bentuk tangganya dipertahankan dari versi sebelumnya; yang berubah artinya.
/// Masukannya bukan nilai terukur melainkan POSISI 0…1 di dalam satu sesi dan
/// satu kebun: 0 paling tertinggal, 1 terdepan. Ia tidak pernah menyatakan
/// kadar klorofil, dan tidak sah dibandingkan antar sesi atau antar kebun.
enum VigorPalette {
    // Fixed nonlinear ramp: improves midrange contrast without normalizing each field.
    static let stops: [(Double, (Double, Double, Double))] = [
        (0, (1, 0.94, 0.12)), (0.2, (0.98, 0.88, 0.12)),
        (0.4, (0.69, 0.82, 0.16)), (0.6, (0.25, 0.66, 0.22)),
        (0.8, (0.06, 0.46, 0.25)), (1, (0.02, 0.30, 0.17))
    ]
    static func color(_ value: Double?) -> Color {
        guard let value, value.isFinite, (0...1).contains(value) else { return .gray }
        for index in 1..<stops.count where value <= stops[index].0 {
            let (low, a) = stops[index - 1], (high, b) = stops[index]
            let t = (value - low) / (high - low)
            return Color(red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t)
        }
        return .green
    }
}

struct VigorLegend: View {
    /// Teks tengah legenda. Selalu sebutkan bahwa skalanya relatif.
    var caption: String = "Posisi relatif"

    var body: some View {
        VStack(spacing: 5) {
            LinearGradient(stops: VigorPalette.stops.map { .init(color: VigorPalette.color($0.0), location: $0.0) },
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 9).clipShape(Capsule())
            HStack {
                Text("tertinggal")
                Spacer()
                Text(caption)
                Spacer()
                Text("terdepan")
            }
            .font(.caption2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(caption): kuning paling tertinggal, hijau terdepan. Abu-abu belum ada data.")
    }
}
