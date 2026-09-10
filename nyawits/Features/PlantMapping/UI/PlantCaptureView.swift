import SwiftUI
import UIKit

struct PlantCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: FieldMappingStore
    @StateObject private var viewModel: PlantCaptureViewModel

    private let onBack: (() -> Void)?
    private let onFinished: (() -> Void)?

    init(
        fieldID: UUID,
        fieldName: String,
        plan: MulchRowPlan,
        existingField: MappedField? = nil,
        onBack: (() -> Void)? = nil,
        onFinished: (() -> Void)? = nil
    ) {
        self.onBack = onBack
        self.onFinished = onFinished
        _viewModel = StateObject(
            wrappedValue: PlantCaptureViewModel(
                fieldID: fieldID,
                fieldName: fieldName,
                plan: plan,
                existingField: existingField
            )
        )
    }

    var body: some View {
        ZStack {
            cameraLayer
                .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.48), .clear, .black.opacity(0.58)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            framingGuide

            VStack(spacing: 12) {
                topBar
                statusArea
                Spacer()
                bottomControls
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.start()
            viewModel.saveProgress(using: store)
        }
        .onDisappear {
            viewModel.stop()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.start() } }
            else { viewModel.stop() }
        }
        .onChange(of: viewModel.selectedRowNumber) { _, _ in viewModel.saveProgress(using: store) }
        .onChange(of: viewModel.selectedSide) { _, _ in viewModel.saveProgress(using: store) }
        .alert("Kamera tidak tersedia", isPresented: errorBinding) {
            Button("Batal", role: .cancel) {}
            Button("Buka Pengaturan") {
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(settingsURL)
            }
        } message: {
            Text(viewModel.errorMessage ?? "Kamera sedang tidak tersedia.")
        }
    }

    private var cameraLayer: some View {
        Group {
            if viewModel.isCameraSupported {
                ARCameraPreview(session: viewModel.session)
            } else {
                ZStack {
                    Color.black
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 48))
                        Text("Pratinjau kamera tersedia di iPhone")
                            .font(.headline)
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            cameraCircleButton(systemName: "chevron.left", action: goBack)
                .accessibilityLabel("Kembali")

            HStack(spacing: 10) {
                Button(action: viewModel.selectPreviousRow) {
                    Image(systemName: "minus")
                        .frame(width: 36, height: 44)
                }
                .disabled(viewModel.selectedRowNumber == 1)

                VStack(spacing: 1) {
                    Text("BARIS")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.selectedRowNumber) dari \(viewModel.plan.rows.count)")
                        .font(.headline.monospacedDigit())
                }
                .frame(minWidth: 76)

                Button(action: viewModel.selectNextRow) {
                    Image(systemName: "plus")
                        .frame(width: 36, height: 44)
                }
                .disabled(viewModel.selectedRowNumber == viewModel.plan.rows.count)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 4)
            .background(.regularMaterial, in: Capsule())
            .disabled(viewModel.isCapturing)

            Spacer()

            Button("Selesai", action: finish)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(height: 48)
                .padding(.horizontal, 16)
                .background(Color.green, in: Capsule())
                .disabled(viewModel.isCapturing)
        }
    }

    private var statusArea: some View {
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

    private var framingGuide: some View {
        GeometryReader { geometry in
            let availableHeight = max(120, geometry.size.height - 425)
            VStack(spacing: 10) {
                Text("Tanaman \(viewModel.currentPlantSequence)")
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

    private var bottomControls: some View {
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

    private var lastPhotoThumbnail: some View {
        Group {
            if let observation = viewModel.latestCapturedObservation,
               let url = store.photoURL(filename: observation.imageFilename),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black.opacity(0.45))
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.65), lineWidth: 1))
    }

    private var trackingColor: Color {
        switch viewModel.trackingQuality {
        case .normal: .green
        case .limited: .orange
        case .unavailable: .red
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel.errorMessage = nil }
            }
        )
    }

    private func cameraCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 48, height: 48)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func goBack() {
        guard viewModel.finish(using: store) else { return }
        if let onBack {
            onBack()
        } else {
            dismiss()
        }
    }

    private func finish() {
        guard viewModel.finish(using: store) else { return }
        if let onFinished {
            onFinished()
        } else {
            dismiss()
        }
    }
}
