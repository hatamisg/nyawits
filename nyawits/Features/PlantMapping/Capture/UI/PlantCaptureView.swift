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
        CaptureStatusBar(viewModel: viewModel, trackingColor: trackingColor)
    }

    private var framingGuide: some View {
        CaptureFramingGuide(currentPlantSequence: viewModel.currentPlantSequence)
    }

    private var bottomControls: some View {
        CaptureControls(viewModel: viewModel, store: store, lastPhotoThumbnail: lastPhotoThumbnail)
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

#if DEBUG
#Preview {
    NavigationStack { PlantCaptureView(fieldID: PreviewFixtures.field.id, fieldName: PreviewFixtures.field.name, plan: PreviewFixtures.field.plan) }.environmentObject(PreviewFixtures.store())
}
#endif
