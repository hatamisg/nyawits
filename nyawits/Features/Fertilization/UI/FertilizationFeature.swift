import SwiftUI

/// Home passes field context here; service integration belongs inside this feature.
struct FertilizationFeature: View {
    let fieldID: UUID?
    let isDemo: Bool

    var body: some View {
        FertilizationCard(content: isDemo ? FertilizationFixtures.demo : FertilizationFixtures.unavailable)
    }
}
