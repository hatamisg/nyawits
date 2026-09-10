import Combine
import SwiftUI
import UIKit

struct MulchRowSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MulchRowSetupViewModel
    @StateObject private var locationService = FieldLocationService()

    private let onBack: (() -> Void)?
    private let onConfirmed: ((MulchRowPlan) -> Void)?

    private let panelMapInset: CGFloat = 310

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

            VStack(spacing: 0) {
                topContent
                Spacer(minLength: 12)
            }

            bottomPanel
        }
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(locationService.$coordinate.compactMap { $0 }) { coordinate in
            viewModel.recenter(on: coordinate)
        }
        .alert("Clear mulch rows?", isPresented: $viewModel.isClearConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive, action: viewModel.clear)
        } message: {
            Text("The row count will be cleared. You can undo this action.")
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

    private var topContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                FloatingMapButton(action: goBack) {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Back")

                VStack(spacing: 2) {
                    Text("Set Mulch Rows")
                        .font(.title3.weight(.bold))
                    Text("Set the count and align the row direction")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .frame(maxWidth: .infinity)

                FloatingMapButton {
                    viewModel.isHelpPresented = true
                } label: {
                    Image(systemName: "questionmark")
                }
                .accessibilityLabel("Help")
            }
            .padding(8)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)

            HStack(alignment: .top) {
                MapStyleToggle(selection: $viewModel.mapStyle)
                    .frame(width: 184)

                Spacer()

                VStack(spacing: 10) {
                    FloatingMapButton(action: locateUser) {
                        Image(systemName: "location.north.fill")
                    }
                    .accessibilityLabel("Show my location")

                    Menu {
                        ForEach(FieldMapStyle.allCases) { style in
                            Button {
                                viewModel.mapStyle = style
                            } label: {
                                if viewModel.mapStyle == style {
                                    Label(style.title, systemImage: "checkmark")
                                } else {
                                    Text(style.title)
                                }
                            }
                        }
                    } label: {
                        mapCircleLabel(systemName: "square.3.layers.3d")
                    }
                    .accessibilityLabel("Map layers")

                    FloatingMapButton(action: viewModel.fitBoundary) {
                        Image(systemName: "scope")
                    }
                    .accessibilityLabel("Fit field boundary")
                }
            }

        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var bottomPanel: some View {
        VStack(spacing: 13) {
            Capsule()
                .fill(Color.secondary.opacity(0.45))
                .frame(width: 38, height: 5)

            MulchRowControls(
                rowCount: viewModel.requestedRowCount,
                rotationDegrees: viewModel.rotationDegrees,
                onRowCountChanged: viewModel.setRowCount,
                onRotationChanged: viewModel.setRotation,
                onRotationEditingChanged: { isEditing in
                    if isEditing {
                        viewModel.beginRotationChange()
                    } else {
                        viewModel.endRotationChange()
                    }
                }
            )

            if let notice = viewModel.notice {
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                FieldActionButton(title: "Undo", icon: "arrow.uturn.backward", action: viewModel.undo)
                    .disabled(!viewModel.canUndo)

                FieldActionButton(title: "Reset", icon: "arrow.counterclockwise", action: viewModel.resetRotation)
                    .disabled(viewModel.rotationDegrees == 0)

                FieldActionButton(title: "Clear", icon: "trash", tint: .red, action: viewModel.requestClear)
                    .disabled(!viewModel.canClear)
            }

            Button(action: confirmRows) {
                Label("Confirm Rows", systemImage: "checkmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.green.opacity(viewModel.canConfirm ? 1 : 0.42), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canConfirm)
            .accessibilityHint(viewModel.canConfirm ? "Confirms these mulch rows" : "Add at least one valid row")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThickMaterial)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        .shadow(color: .black.opacity(0.14), radius: 18, y: -4)
        .ignoresSafeArea(edges: .bottom)
    }

    private func mapCircleLabel(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.primary)
            .frame(width: 52, height: 52)
            .background(.regularMaterial, in: Circle())
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
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
