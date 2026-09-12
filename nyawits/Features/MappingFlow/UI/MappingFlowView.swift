import SwiftUI

struct MappingFlowView: View {
    @Environment(\.dismiss) private var dismiss

    let fieldID: UUID
    let fieldName: String

    @State private var boundary: FieldBoundary?
    @State private var rowPlan: MulchRowPlan?

    var body: some View {
        Group {
            if let rowPlan {
                PlantCaptureView(
                    fieldID: fieldID,
                    fieldName: fieldName,
                    plan: rowPlan,
                    onBack: dismiss.callAsFunction,
                    onFinished: dismiss.callAsFunction
                )
            } else if let boundary {
                MulchRowSetupView(
                    boundary: boundary,
                    onBack: { self.boundary = nil },
                    onConfirmed: { rowPlan = $0 }
                )
            } else {
                FieldAreaSelectionView(
                    onCancel: dismiss.callAsFunction,
                    onConfirmed: { boundary = $0 }
                )
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { MappingFlowView(fieldID: PreviewFixtures.field.id, fieldName: "Kebun Baru") }.previewStores()
}
#endif
