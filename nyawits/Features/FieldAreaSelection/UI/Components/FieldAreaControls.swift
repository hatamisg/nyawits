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

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Button(action: action) {
            label()
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .modifier(DarkGlassControlSurface(shape: AnyShape(Circle()), interactive: true, opaque: reduceTransparency))
        }
        .buttonStyle(.plain)
    }
}

struct FieldMapControlCluster: View {
    @Binding var selection: FieldMapStyle
    let onHelp: () -> Void
    let onLocate: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 12) {
                    controls
                }
            } else {
                controls
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Map controls")
    }

    private var controls: some View {
        VStack(spacing: 12) {
            FloatingMapButton(action: onHelp) {
                Image(systemName: "questionmark")
            }
            .accessibilityLabel("Help")

            VStack(spacing: 0) {
                Menu {
                    ForEach(FieldMapStyle.allCases) { style in
                        Button {
                            selection = style
                        } label: {
                            if selection == style {
                                Label(style.title, systemImage: "checkmark")
                            } else {
                                Text(style.title)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "square.3.layers.3d")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Map layers")
                .accessibilityValue(selection.title)

                Divider()
                    .overlay(.white.opacity(0.18))
                    .padding(.horizontal, 10)
                    .accessibilityHidden(true)

                Button(action: onLocate) {
                    Image(systemName: "location.north.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show my location")
            }
            .frame(width: 48)
            .modifier(DarkGlassControlSurface(shape: AnyShape(Capsule()), interactive: false, opaque: reduceTransparency))
        }
        .fixedSize(horizontal: true, vertical: false)
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
                .font(.title3.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
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
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .padding(.horizontal, 14)
                .frame(minWidth: 92, minHeight: 46)
                .background(.white.opacity(0.1), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

struct FieldSelectionPanelSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)

    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content
                .background(Color.black.opacity(0.92), in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.24), radius: 20, y: 8)
        } else if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.black.opacity(0.58)), in: shape)
                .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(Color.black.opacity(0.52), in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.16), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
        }
    }
}

private struct DarkGlassControlSurface: ViewModifier {
    let shape: AnyShape
    let interactive: Bool
    let opaque: Bool

    func body(content: Content) -> some View {
        if opaque {
            content
                .background(Color.black.opacity(0.88), in: shape)
                .overlay(shape.stroke(.white.opacity(0.2), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        } else if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    interactive
                        ? .regular.tint(.black.opacity(0.48)).interactive()
                        : .regular.tint(.black.opacity(0.48)),
                    in: shape
                )
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .background(Color.black.opacity(0.46), in: shape)
                .overlay(shape.stroke(.white.opacity(0.16), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        }
    }
}
