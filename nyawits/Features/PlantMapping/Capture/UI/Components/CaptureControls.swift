import SwiftUI
import UIKit

struct CaptureControls<Thumbnail: View>: View {
    @ObservedObject var viewModel: PlantCaptureViewModel
    @ObservedObject var store: FieldMappingStore
    let lastPhotoThumbnail: Thumbnail
    var body: some View {
        VStack(spacing: 14) {
            Text(viewModel.sideGuide)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            Picker("Sisi tanaman", selection: $viewModel.selectedSide) {
                ForEach(PlantCaptureSide.allCases) { side in
                    Text(side.title).tag(side)
                }
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.isCapturing)
            .accessibilityHint("Sisi mengikuti arah mata angin, tetap sama saat Anda berbalik")

            HStack {
                Button {
                    viewModel.undoLast(using: store)
                } label: {
                    lastPhotoThumbnail
                }
                .disabled(viewModel.observations.isEmpty || viewModel.isCapturing)
                .accessibilityLabel("Batalkan tanaman terakhir")

                Spacer()

                Button {
                    Task {
                        await viewModel.capture(using: store)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(.white, lineWidth: 5)
                            .frame(width: 78, height: 78)
                        Circle()
                            .fill(.white)
                            .frame(width: 62, height: 62)
                        if viewModel.isCapturing {
                            ProgressView()
                                .tint(.green)
                        }
                    }
                }
                .disabled(!viewModel.isCameraRunning || viewModel.isCapturing || viewModel.currentSideIsComplete)
                .accessibilityLabel("Foto tanaman \(viewModel.currentPlantSequence)")

                Spacer()

                Button {
                    viewModel.skipCurrentPlant(using: store)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "forward.end.fill")
                            .font(.title3)
                        Text("Lewati")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(.black.opacity(0.5), in: Circle())
                }
                .accessibilityLabel("Lewati tanaman \(viewModel.currentPlantSequence)")
                .disabled(viewModel.isCapturing || viewModel.currentSideIsComplete)
            }

            HStack {
                Text("\(viewModel.capturedPlantCount) foto")
                Spacer()
                Button {
                    viewModel.toggleSideComplete(using: store)
                } label: {
                    Label(viewModel.currentSideIsComplete ? "Buka lagi" : "Sisi ini selesai",
                          systemImage: viewModel.currentSideIsComplete ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .disabled(viewModel.isCapturing)
                .frame(minHeight: 44)
            }
            .font(.caption.weight(.semibold))
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
    
    }

}

#if DEBUG
#Preview {
    CaptureControls(viewModel: PreviewFixtures.captureModel(), store: PreviewFixtures.store(), lastPhotoThumbnail: Image(systemName: "leaf.fill").frame(width: 48, height: 48)).padding()
}
#endif
