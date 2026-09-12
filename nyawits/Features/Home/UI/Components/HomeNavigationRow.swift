import SwiftUI

struct HomeNavigationRow: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.green)
                    .frame(width: 28)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(minHeight: 58)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
