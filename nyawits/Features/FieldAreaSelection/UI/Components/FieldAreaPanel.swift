import SwiftUI

struct FieldAreaPanel: View {
    @ObservedObject var viewModel: FieldAreaSelectionViewModel
    @Binding var panelHeight: CGFloat
    let confirmBoundary: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(.white.opacity(0.42))
                .frame(width: 36, height: 5)
                .accessibilityHidden(true)

            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    FieldActionButton(title: "Undo", icon: "arrow.uturn.backward", action: viewModel.undo)
                        .disabled(viewModel.points.isEmpty)

                    FieldActionButton(title: "Clear", icon: "trash", tint: .white, backgroundColor: .red, action: viewModel.requestClear)
                        .disabled(viewModel.points.isEmpty)
                }

                Spacer(minLength: 0)

                FieldMetricView(
                    icon: "point.3.connected.trianglepath.dotted",
                    iconColor: .green,
                    value: "\(viewModel.points.count) points",
                    label: "Field boundary"
                )
                .fixedSize(horizontal: true, vertical: false)
            }

            if let warning = viewModel.validationMessage ?? viewModel.notice {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: confirmBoundary) {
                Label("Confirm Field Area", systemImage: "checkmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.green.opacity(viewModel.canConfirm ? 0.92 : 0.32), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(viewModel.canConfirm ? 0.2 : 0.08), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canConfirm)
            .accessibilityHint(viewModel.canConfirm ? "Confirms this boundary" : "Add at least three non-crossing points")
        }
        .padding(.horizontal, 16)
        .padding(.top, 9)
        .padding(.bottom, 16)
        .modifier(FieldSelectionPanelSurface())
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newHeight in
            guard abs(panelHeight - newHeight) > 1 else { return }
            panelHeight = newHeight
        }
    
    }
}
