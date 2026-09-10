import SwiftUI
import UIKit

struct MapStyleToggle: View {
    @Binding var selection: FieldMapStyle

    var body: some View {
        HStack(spacing: 0) {
            styleButton(title: "Map", style: .standard)
            styleButton(title: "Satellite", style: .satellite)
        }
        .padding(3)
        .background(.black.opacity(0.56), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.38), lineWidth: 0.5))
    }

    private func styleButton(title: String, style: FieldMapStyle) -> some View {
        let selected = selection == style || (style == .satellite && selection == .hybrid)

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selection = style
            }
        } label: {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(selected ? Color.black.opacity(0.62) : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct FloatingMapButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 52, height: 52)
                .background(.regularMaterial, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

struct FieldMetricView: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}

struct FieldActionButton: View {
    let title: String
    let icon: String
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
