import SwiftUI

struct MulchRowPanel: View {
    @ObservedObject var viewModel: MulchRowSetupViewModel
    @Binding var panelHeight: CGFloat
    let confirmRows: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(.white.opacity(0.42))
                .frame(width: 36, height: 5)
                .accessibilityHidden(true)

            MulchRowControls(
                boundary: viewModel.boundary,
                rowCount: viewModel.requestedRowCount,
                rotationDegrees: viewModel.rotationDegrees,
                onRowCountChanged: viewModel.setRowCount,
                onRotationChanged: viewModel.setRotation,
                onRotationEditingChanged: { isEditing in
                    if isEditing {
                        viewModel.beginRotationChange()
                    } else {
                        viewModel.endRotationChange()
                    }
                }
            )

            if let notice = viewModel.notice {
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }


            Button(action: confirmRows) {
                Label("Confirm Rows", systemImage: "checkmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.green.opacity(viewModel.canConfirm ? 0.92 : 0.32), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(viewModel.canConfirm ? 0.2 : 0.08), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canConfirm)
            .accessibilityHint(viewModel.canConfirm ? "Confirms these mulch rows" : "Add at least one valid row")
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
