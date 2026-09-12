import SwiftUI

struct MulchRowMapOverlay: View {
    @ObservedObject var viewModel: MulchRowSetupViewModel
    let panelMapInset: CGFloat
    let locateUser: () -> Void
    let goBack: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Set Mulch Rows")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .shadow(color: .black.opacity(0.75), radius: 5, y: 1)
                    .padding(.horizontal, 64)

                FloatingMapButton(action: goBack) {
                    Image(systemName: "chevron.left")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Back")
            }

            Spacer(minLength: 16)

            FieldMapControlCluster(
                selection: $viewModel.mapStyle,
                onHelp: {
                    viewModel.isHelpPresented = true
                },
                onLocate: locateUser
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.bottom, panelMapInset)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    
    }
}

#if DEBUG
#Preview {
    MulchRowMapOverlay(viewModel: PreviewFixtures.rowModel(), panelMapInset: 240, locateUser: {}, goBack: {}).background(.green.gradient)
}
#endif
