import SwiftUI
import UIKit

struct HomeHeader: View {
    let effectiveTitleText: String
    let effectiveTitleFontSize: CGFloat
    /// Logo ikut tumbuh bersama ukuran teks; kalau dipatok, ia menyusut relatif
    /// terhadap judul di ukuran aksesibilitas dan tata letaknya jadi timpang.
    @ScaledMetric(relativeTo: .largeTitle) private var logoSize: CGFloat = 56
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
                .frame(width: logoSize, height: logoSize)
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
