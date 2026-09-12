import SwiftUI
import UIKit

struct CaptureFramingGuide: View {
    let currentPlantSequence: Int
    var body: some View {
        GeometryReader { geometry in
            let availableHeight = max(120, geometry.size.height - 425)
            VStack(spacing: 10) {
                Text("Tanaman \(currentPlantSequence)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(.black.opacity(0.48), in: Capsule())
                RoundedRectangle(cornerRadius: 34)
                    .stroke(.white.opacity(0.78), style: StrokeStyle(lineWidth: 2, dash: [12, 9]))
                    .frame(width: min(260, geometry.size.width - 48), height: max(80, availableHeight - 46))
            }
            .frame(width: geometry.size.width, height: availableHeight)
            .position(x: geometry.size.width / 2, y: 130 + availableHeight / 2)
        }
        .allowsHitTesting(false)
    
    }

}
