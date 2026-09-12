import SwiftUI

/// Shared plant-health colours used by both the spatial heatmap and compact cards.
enum PlantHealthPalette {
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
            return Color(red: a.0 + (b.0 - a.0) * t,
                         green: a.1 + (b.1 - a.1) * t,
                         blue: a.2 + (b.2 - a.2) * t)
        }
        return .green
    }
}
