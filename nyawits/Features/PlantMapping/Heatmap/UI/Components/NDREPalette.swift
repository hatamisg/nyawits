import SwiftUI

enum NDREPalette {
    // Fixed nonlinear ramp: improves midrange contrast without normalizing each field.
    static let stops = PlantHealthPalette.stops
    static func color(_ value: Double?) -> Color {
        PlantHealthPalette.color(value)
    }
}

struct NDRELegend: View {
    var body: some View {
        VStack(spacing: 5) {
            LinearGradient(stops: NDREPalette.stops.map { .init(color: NDREPalette.color($0.0), location: $0.0) },
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 9).clipShape(Capsule())
            HStack {
                Text("0 · rendah")
                Spacer()
                Text("NDRE")
                Spacer()
                Text("1 · tinggi")
            }
            .font(.caption2.monospacedDigit())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("NDRE: nol kuning, satu hijau. Abu-abu belum ada data.")
    }
}

#if DEBUG
#Preview {
    NDRELegend().padding().background(.green)
}
#endif
