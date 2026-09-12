import SwiftUI
import UIKit

struct CaptureStatusBar: View {
    @ObservedObject var viewModel: PlantCaptureViewModel
    let trackingColor: Color
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                Circle()
                    .fill(trackingColor)
                    .frame(width: 8, height: 8)
                Text(viewModel.trackingMessage)
                Text("•")
                Text(viewModel.locationStatus)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(.black.opacity(0.52), in: Capsule())

            if !viewModel.isMotionStable {
                Label("Tahan sebentar", systemImage: "hand.raised.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Color.orange.opacity(0.88), in: Capsule())
            }
        }
    
    }

}

#if DEBUG
#Preview {
    CaptureStatusBar(viewModel: PreviewFixtures.captureModel(), trackingColor: .orange).padding().background(.black)
}
#endif
