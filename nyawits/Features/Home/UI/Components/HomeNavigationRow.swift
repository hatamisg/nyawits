import SwiftUI

struct HomeNavigationRow: View {
    let title: String
    let symbol: String
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var symbolWidth: CGFloat = 28
    /// 44pt adalah sasaran sentuh minimum HIG; 58 memberi ruang lega di atasnya.
    @ScaledMetric(relativeTo: .body) private var rowMinHeight: CGFloat = 58

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.green)
                    .frame(width: symbolWidth)
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
            .frame(minHeight: max(44, rowMinHeight))
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    HomeNavigationRow(title: "Tambah Kebun", symbol: "plus", action: {}).padding()
}
#endif
