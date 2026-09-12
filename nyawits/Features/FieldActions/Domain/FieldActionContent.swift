import Foundation

/// Presentation-ready result of an action recommendation.
/// It is intentionally independent from field geometry and stored camera data.
struct FieldActionFocus {
    let headline: String
    let rowNumber: Int
    let areaLabel: String
    let plants: [FieldActionPlant]
    let actionTitle: String
    let actionSystemImage: String
}

struct FieldActionPlant: Identifiable, Equatable {
    let id: Int
    let sequence: Int
    let ndre: Double?
    let needsAttention: Bool

    init(sequence: Int, ndre: Double?, needsAttention: Bool) {
        id = sequence
        self.sequence = sequence
        self.ndre = ndre
        self.needsAttention = needsAttention
    }
}

struct FieldActionContent {
    let isSimulation: Bool
    let message: String
    let note: String
    let focus: FieldActionFocus?
}
