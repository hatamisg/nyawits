import SwiftUI

/// Tangga warna posisi vigor RELATIF.
///
/// Bentuk tangganya dipertahankan dari versi sebelumnya; yang berubah artinya.
/// Masukannya bukan nilai terukur melainkan POSISI 0…1 di dalam satu sesi dan
/// satu kebun: 0 paling tertinggal, 1 terdepan. Ia tidak pernah menyatakan
/// kadar klorofil, dan tidak sah dibandingkan antar sesi atau antar kebun.
enum VigorPalette {
    // Fixed nonlinear ramp: improves midrange contrast without normalizing each field.
    static let stops = PlantHealthPalette.stops
    static func color(_ value: Double?) -> Color {
        PlantHealthPalette.color(value)
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

#if DEBUG
#Preview {
    VigorLegend().padding().background(.green)
}
#endif
