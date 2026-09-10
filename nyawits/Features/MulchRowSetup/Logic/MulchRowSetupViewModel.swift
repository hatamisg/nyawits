import Combine
import CoreLocation
import Foundation

@MainActor
final class MulchRowSetupViewModel: ObservableObject {
    let boundary: FieldBoundary

    @Published private(set) var rows: [MulchRow] = []
    @Published private(set) var requestedRowCount = 0
    @Published private(set) var rotationDegrees = 0.0
    @Published var mapStyle: FieldMapStyle = .satellite
    @Published var recenterRequest: MapRecenterRequest?
    @Published var fitBoundaryRequestID = UUID()
    @Published var isHelpPresented = false
    @Published var isClearConfirmationPresented = false
    @Published var isPlanReadyPresented = false
    @Published var notice: String?

    private struct Configuration: Equatable {
        let rowCount: Int
        let rotationDegrees: Double
    }

    private var history: [Configuration] = []
    private var isChangingRotation = false

    init(
        boundary: FieldBoundary,
        rowCount: Int = 0,
        rotationDegrees: Double = 0
    ) {
        self.boundary = boundary
        requestedRowCount = min(200, max(0, rowCount))
        self.rotationDegrees = MulchRowGeometryCalculator.normalizedRotation(rotationDegrees)
        rows = MulchRowGeometryCalculator.generatedRows(
            count: requestedRowCount,
            rotationDegrees: self.rotationDegrees,
            inside: boundary
        )
    }

    var canConfirm: Bool {
        requestedRowCount > 0 && rows.count == requestedRowCount
    }

    var canUndo: Bool {
        !history.isEmpty
    }

    var canClear: Bool {
        requestedRowCount > 0
    }

    func setRowCount(_ count: Int) {
        let validCount = min(200, max(0, count))
        guard validCount != requestedRowCount else { return }
        saveHistory()
        requestedRowCount = validCount
        regenerateRows()
    }

    func beginRotationChange() {
        guard !isChangingRotation else { return }
        saveHistory()
        isChangingRotation = true
    }

    func setRotation(_ degrees: Double) {
        rotationDegrees = MulchRowGeometryCalculator.normalizedRotation(degrees)
        regenerateRows()
    }

    func endRotationChange() {
        isChangingRotation = false
    }

    func rotate(by degrees: Double) {
        saveHistory()
        rotationDegrees = MulchRowGeometryCalculator.normalizedRotation(rotationDegrees + degrees)
        regenerateRows()
    }

    func resetRotation() {
        guard rotationDegrees != 0 else { return }
        saveHistory()
        rotationDegrees = 0
        regenerateRows()
    }

    func undo() {
        guard let configuration = history.popLast() else { return }
        isChangingRotation = false
        requestedRowCount = configuration.rowCount
        rotationDegrees = configuration.rotationDegrees
        regenerateRows()
    }

    func requestClear() {
        guard canClear else { return }
        isClearConfirmationPresented = true
    }

    func clear() {
        saveHistory()
        requestedRowCount = 0
        rows = []
        notice = nil
    }

    func recenter(on coordinate: CLLocationCoordinate2D) {
        recenterRequest = MapRecenterRequest(coordinate: coordinate)
    }

    func fitBoundary() {
        fitBoundaryRequestID = UUID()
    }

    func confirm() -> MulchRowPlan? {
        guard canConfirm else { return nil }
        let plan = MulchRowPlan(
            boundary: boundary,
            rows: rows,
            rotationDegrees: rotationDegrees
        )
        isPlanReadyPresented = true
        return plan
    }

    private func regenerateRows() {
        guard requestedRowCount > 0 else {
            rows = []
            notice = nil
            return
        }

        rows = MulchRowGeometryCalculator.generatedRows(
            count: requestedRowCount,
            rotationDegrees: rotationDegrees,
            inside: boundary
        )
        notice = rows.count == requestedRowCount
            ? nil
            : "This field shape cannot fit all requested rows at this angle."
    }

    private func saveHistory() {
        let current = Configuration(
            rowCount: requestedRowCount,
            rotationDegrees: rotationDegrees
        )
        guard history.last != current else { return }
        history.append(current)
        if history.count > 30 {
            history.removeFirst()
        }
    }
}
