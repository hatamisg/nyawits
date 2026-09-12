import SwiftUI
import UIKit

struct HomeHeader: View {
    let effectiveTitleText: String
    let effectiveTitleFontSize: CGFloat
    var body: some View {
        HStack {
            Text(effectiveTitleText)
                .font(AveriaFont.bold(size: max(40, effectiveTitleFontSize), relativeTo: .largeTitle))
                .foregroundStyle(Color.kropsGreen)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Image("ikonmodul")
                .resizable()
                .scaledToFit()
                .padding(10)
                .frame(width: 56, height: 56)
                .background(.white.opacity(0.9), in: Circle())
                .accessibilityLabel("Logo modul")
        }
        .padding(.horizontal, 8)
        .padding(.top, 24)
        .padding(.bottom, 6)
    
    }

}

#if DEBUG
#Preview {
    HomeHeader(effectiveTitleText: "Krops", effectiveTitleFontSize: 40).padding()
}
#endif
