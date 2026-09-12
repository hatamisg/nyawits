import Combine
import CoreLocation
import SwiftUI
import UIKit

struct FieldAreaSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FieldAreaSelectionViewModel
    @StateObject private var locationService = FieldLocationService()
    @State private var panelHeight: CGFloat = 0
    @State private var hasShownDiscovery = false

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

            if viewModel.isHelpPresented {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            viewModel.isHelpPresented = false
                        }
                    }
                    .zIndex(100)

                FieldAreaDiscoverySheet(onDismiss: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        viewModel.isHelpPresented = false
                    }
                })
                .transition(.move(edge: .bottom))
                .ignoresSafeArea(edges: .bottom)
                .zIndex(101)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: viewModel.isHelpPresented)
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
        .task {
            guard viewModel.fitRequest == nil, !hasShownDiscovery else { return }
            hasShownDiscovery = true
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                viewModel.isHelpPresented = true
            }
        }
    }

    private var mapOverlay: some View {
        FieldAreaMapOverlay(viewModel: viewModel, panelMapInset: panelMapInset, locateUser: locateUser, title: title, subtitle: subtitle, close: close)
    }

    private var bottomPanel: some View {
        FieldAreaPanel(viewModel: viewModel, panelHeight: $panelHeight, confirmBoundary: confirmBoundary)
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

#if DEBUG
#Preview("Batas terpilih") {
    NavigationStack { FieldAreaSelectionView(initialBoundary: PreviewFixtures.boundary) }
}
#Preview("Batas kosong") {
    NavigationStack { FieldAreaSelectionView() }
}
#endif
