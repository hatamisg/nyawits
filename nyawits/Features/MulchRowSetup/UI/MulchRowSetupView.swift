import Combine
import SwiftUI
import UIKit

struct MulchRowSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MulchRowSetupViewModel
    @StateObject private var locationService = FieldLocationService()

    private let onBack: (() -> Void)?
    private let onConfirmed: ((MulchRowPlan) -> Void)?

    @State private var panelHeight: CGFloat = 300
    private let minimumPanelMapInset: CGFloat = 240

    private var panelMapInset: CGFloat {
        max(minimumPanelMapInset, panelHeight + 16)
    }

    init(
        boundary: FieldBoundary,
        initialRowCount: Int = 0,
        initialRotationDegrees: Double = 0,
        onBack: (() -> Void)? = nil,
        onConfirmed: ((MulchRowPlan) -> Void)? = nil
    ) {
        self.onBack = onBack
        self.onConfirmed = onConfirmed
        _viewModel = StateObject(
            wrappedValue: MulchRowSetupViewModel(
                boundary: boundary,
                rowCount: initialRowCount,
                rotationDegrees: initialRotationDegrees
            )
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MulchRowMapView(
                boundary: viewModel.boundary,
                rows: viewModel.rows,
                rotationDegrees: viewModel.rotationDegrees,
                mapStyle: viewModel.mapStyle,
                userCoordinate: locationService.coordinate,
                userHorizontalAccuracy: locationService.horizontalAccuracy,
                recenterRequest: viewModel.recenterRequest,
                fitBoundaryRequestID: viewModel.fitBoundaryRequestID,
                bottomContentInset: panelMapInset,
                onRotationBegan: viewModel.beginRotationChange,
                onRotationChanged: viewModel.setRotation,
                onRotationEnded: viewModel.endRotationChange
            )
            .ignoresSafeArea()

            mapOverlay

            bottomPanel
        }
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(locationService.$coordinate.compactMap { $0 }) { coordinate in
            viewModel.recenter(on: coordinate)
        }
        .alert("Set mulch rows", isPresented: $viewModel.isHelpPresented) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("Enter the number of mulch rows, then use the slider or twist two fingers on the map to rotate them. Every row automatically ends at the field boundary.")
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
        .alert("Mulch rows ready", isPresented: $viewModel.isPlanReadyPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The mulch rows are ready for photo mapping.")
        }
    }

    private var mapOverlay: some View {
        MulchRowMapOverlay(viewModel: viewModel, panelMapInset: panelMapInset, locateUser: locateUser, goBack: goBack)
    }

    private var bottomPanel: some View {
        MulchRowPanel(viewModel: viewModel, panelHeight: $panelHeight, confirmRows: confirmRows)
    }

    private func locateUser() {
        if let coordinate = locationService.coordinate {
            viewModel.recenter(on: coordinate)
        } else {
            locationService.requestLocation()
        }
    }

    private func confirmRows() {
        guard let plan = viewModel.confirm() else { return }
        if let onConfirmed {
            viewModel.isPlanReadyPresented = false
            onConfirmed(plan)
        }
    }

    private func goBack() {
        if let onBack {
            onBack()
        } else {
            dismiss()
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { MulchRowSetupView(boundary: PreviewFixtures.boundary, initialRowCount: 10) }
}
#endif
