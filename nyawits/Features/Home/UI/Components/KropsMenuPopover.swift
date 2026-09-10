import SwiftUI

/// PreferenceKey untuk mengukur frame global tombol judul Krops
struct KropsTitleFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

/// A compact navigation panel with one native Liquid Glass surface.
struct KropsMenuPanel: View {
    let onSelectList: () -> Void
    let onSelectAdd: () -> Void
    var availableWidth: CGFloat = 320

    @ScaledMetric(relativeTo: .body) private var preferredWidth = 215.0
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
    }

    var body: some View {
        VStack(spacing: 0) {
            menuButton("Daftar Kebun", symbol: "list.bullet", action: onSelectList)
            Divider()
                .overlay(Color.primary.opacity(0.04))
                .padding(.horizontal, 16)
                .accessibilityHidden(true)
            menuButton("Tambah Kebun", symbol: "plus", action: onSelectAdd)
        }
        .padding(6)
        .frame(width: min(preferredWidth, max(availableWidth, 44)))
        .modifier(MenuSurface(shape: shape, opaque: reduceTransparency || contrast == .increased))
    }

    private func menuButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.body.weight(.medium))
                    .frame(width: 22)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct MenuSurface: ViewModifier {
    let shape: RoundedRectangle
    let opaque: Bool

    func body(content: Content) -> some View {
        if opaque {
            content
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        } else {
            content.glassEffect(.regular, in: shape)
        }
    }
}
