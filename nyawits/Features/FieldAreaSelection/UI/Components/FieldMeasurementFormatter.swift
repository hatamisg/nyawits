import Foundation

enum FieldMeasurementFormatter {
    static func distance(_ meters: Double) -> String {
        if meters >= 1_000 {
            return String(format: "%.2f km", meters / 1_000)
        }
        return String(format: "%.1f m", meters)
    }

    static func area(_ squareMeters: Double) -> String {
        if squareMeters >= 10_000 {
            return String(format: "%.2f ha", squareMeters / 10_000)
        }
        return String(format: "%.0f m²", squareMeters)
    }
}
