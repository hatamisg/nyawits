import Combine
import CoreLocation
import SwiftUI
import UIKit

struct FieldAreaSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FieldAreaSelectionViewModel
    @StateObject private var locationService = FieldLocationService()

    private let title: String
    private let subtitle: String
    private let onCancel: (() -> Void)?
    private let onConfirmed: ((FieldBoundary) -> Void)?

    private let panelMapInset: CGFloat = 252

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

            VStack(spacing: 0) {
                topContent
                Spacer(minLength: 16)
            }

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

    private var topContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                FloatingMapButton(action: close) {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Back")

                VStack(spacing: 2) {
                    Text(title)
                        .font(.title3.weight(.bold))
                    Text(subtitle)
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
                        Image(systemName: "square.3.layers.3d")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.primary)
                            .frame(width: 52, height: 52)
                            .background(.regularMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    }
                    .accessibilityLabel("Map layers")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var bottomPanel: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(Color.secondary.opacity(0.45))
                .frame(width: 38, height: 5)

            metrics

            if let warning = viewModel.validationMessage ?? viewModel.notice {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                FieldActionButton(title: "Undo", icon: "arrow.uturn.backward", action: viewModel.undo)
                    .disabled(viewModel.points.isEmpty)

                FieldActionButton(title: "Clear", icon: "trash", tint: .red, action: viewModel.requestClear)
                    .disabled(viewModel.points.isEmpty)

                FieldActionButton(title: "My Location", icon: "scope", action: locateUser)
            }

            Button(action: confirmBoundary) {
                Label("Confirm Field Area", systemImage: "checkmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.green.opacity(viewModel.canConfirm ? 1 : 0.42), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canConfirm)
            .accessibilityHint(viewModel.canConfirm ? "Confirms this boundary" : "Add at least three non-crossing points")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThickMaterial)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        .shadow(color: .black.opacity(0.14), radius: 18, y: -4)
        .ignoresSafeArea(edges: .bottom)
    }

    private var metrics: some View {
        HStack(spacing: 10) {
            FieldMetricView(
                icon: "point.3.connected.trianglepath.dotted",
                iconColor: .green,
                value: "\(viewModel.points.count) points",
                label: "Field boundary"
            )

            Divider().frame(height: 50)

            FieldMetricView(
                icon: "square.dashed",
                iconColor: .secondary,
                value: FieldMeasurementFormatter.area(viewModel.areaSquareMeters),
                label: "Estimated area"
            )

            Divider().frame(height: 50)

            FieldMetricView(
                icon: "ruler",
                iconColor: .secondary,
                value: FieldMeasurementFormatter.distance(viewModel.perimeterMeters),
                label: "Total perimeter"
            )
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
