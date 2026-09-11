import Foundation

struct FertilizationDate: Identifiable {
    let id: String
    let day: Int
    let month: String
    let isHighlighted: Bool
}

/// Presentation-ready content; no weather decisions are inferred by the UI.
struct FertilizationContent {
    let isSimulation: Bool
    let dates: [FertilizationDate]
    let detail: String
}
