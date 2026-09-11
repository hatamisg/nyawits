import SwiftUI

struct FieldActionsFeature: View {
    let fieldID: UUID?
    let isDemo: Bool

    var body: some View {
        FieldActionCard(content: isDemo ? FieldActionFixtures.demo : FieldActionFixtures.unavailable)
    }
}
