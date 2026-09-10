import Combine
import CoreLocation
import SwiftUI
import UIKit

struct FieldAreaSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FieldAreaSelectionViewModel
    @StateObject private var locationService = FieldLocationService()
    @State private var panelHeight: CGFloat = 0

    private let title: String
    private let subtitle: String
    private let onCancel: (() -> Void)?
    private let onConfirmed: ((FieldBoundary) -> Void)?

    private let minimumPanelMapInset: CGFloat = 224

    private var panelMapInset: CGFloat {
        max(minimumPanelMapInset, panelHeight + 16)
    }

    /// Mode edit (`initialBoundary != nil`): peta memuat boundary tersimpan dan
    /// pembaruan GPS tidak menggeser kamera sehingga boundary lama tetap terlihat.
    init(
        title: String = "Select Field Area",
        subtitle: String = "Tap on the map to add boundary points",
        initialBoundary: FieldBoundary? = nil,
        onCancel: (() -> Void)? = nil,
        onConfirmed: ((FieldBoundary) -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onCancel = onCancel
        self.onConfirmed = onConfirmed
        _viewModel = StateObject(
            wrappedValue: FieldAreaSelectionViewModel(initialBoundary: initialBoundary)
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            FieldMapView(
                points: viewModel.points,
                mapStyle: viewModel.mapStyle,
                userCoordinate: locationService.coordinate,
                recenterRequest: viewModel.recenterRequest,
                fitRequest: viewModel.fitRequest,
                bottomContentInset: panelMapInset,
                onMapTap: viewModel.addPoint,
                onPointMoved: viewModel.movePoint
            )
            .ignoresSafeArea()

            mapOverlay

            bottomPanel
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(false)
        .onReceive(locationService.$coordinate.compactMap { $0 }) { coordinate in
            guard viewModel.fitRequest == nil else { return }
            viewModel.recenter(on: coordinate)
        }
        .alert("Clear field boundary?", isPresented: $viewModel.isClearConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive, action: viewModel.clear)
        } message: {
            Text("All boundary points will be removed.")
        }
        .alert("Select a field area", isPresented: $viewModel.isHelpPresented) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("Tap the map to add at least three boundary points. Drag a numbered marker to adjust it. Boundary lines can’t cross.")
        }
        .alert("Location unavailable", isPresented: $locationService.isPermissionAlertPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") {
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(settingsURL)
            }
        } message: {
            Text(locationService.errorMessage)
        }
        .fullScreenCover(item: $viewModel.confirmedBoundary) { boundary in
            MulchRowSetupView(boundary: boundary)
        }
    }

    private var mapOverlay: some View {
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
                onHelp: { viewModel.isHelpPresented = true },
                onLocate: locateUser
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.bottom, panelMapInset + 16)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var bottomPanel: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(.white.opacity(0.42))
                .frame(width: 36, height: 5)
                .accessibilityHidden(true)

            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    FieldActionButton(title: "Undo", icon: "arrow.uturn.backward", action: viewModel.undo)
                        .disabled(viewModel.points.isEmpty)

                    FieldActionButton(title: "Clear", icon: "trash", tint: .red, action: viewModel.requestClear)
                        .disabled(viewModel.points.isEmpty)
                }

                Spacer(minLength: 0)

                FieldMetricView(
                    icon: "point.3.connected.trianglepath.dotted",
                    iconColor: .green,
                    value: "\(viewModel.points.count) points",
                    label: "Field boundary"
                )
                .fixedSize(horizontal: true, vertical: false)
            }

            if let warning = viewModel.validationMessage ?? viewModel.notice {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: confirmBoundary) {
                Label("Confirm Field Area", systemImage: "checkmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.green.opacity(viewModel.canConfirm ? 0.92 : 0.32), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(viewModel.canConfirm ? 0.2 : 0.08), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canConfirm)
            .accessibilityHint(viewModel.canConfirm ? "Confirms this boundary" : "Add at least three non-crossing points")
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

    private func locateUser() {
        if let coordinate = locationService.coordinate {
            viewModel.recenter(on: coordinate)
        } else {
            locationService.requestLocation()
        }
    }

    private func confirmBoundary() {
        guard let boundary = viewModel.confirm() else { return }
        if let onConfirmed {
            viewModel.confirmedBoundary = nil
            onConfirmed(boundary)
        }
    }

    private func close() {
        if let onCancel {
            onCancel()
        } else {
            dismiss()
        }
    }
}

struct FieldAreaSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        FieldAreaSelectionView()
    }
}
