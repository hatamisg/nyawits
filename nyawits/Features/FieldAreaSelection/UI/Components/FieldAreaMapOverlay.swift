import SwiftUI

struct FieldAreaMapOverlay: View {
    @ObservedObject var viewModel: FieldAreaSelectionViewModel
    let panelMapInset: CGFloat
    let locateUser: () -> Void
    let title: String
    let subtitle: String
    let close: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .shadow(color: .black.opacity(0.75), radius: 5, y: 1)
                    .padding(.horizontal, 64)
                    .accessibilityHint(subtitle)

                FloatingMapButton(action: close) {
                    Image(systemName: "chevron.left")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Back")
            }

            Spacer(minLength: 16)

            FieldMapControlCluster(
                selection: $viewModel.mapStyle,
                onHelp: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        viewModel.isHelpPresented = true
                    }
                },
                onLocate: locateUser
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.bottom, panelMapInset - 35)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    
    }
}

#if DEBUG
#Preview {
    FieldAreaMapOverlay(viewModel: PreviewFixtures.areaModel(), panelMapInset: 224, locateUser: {}, title: "Select Field Area", subtitle: "Tap to add boundary points", close: {}).background(.green.gradient)
}
#endif
