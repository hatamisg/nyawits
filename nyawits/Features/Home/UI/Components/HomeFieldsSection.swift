import SwiftUI
import UIKit

struct HomeFieldsSection: View {
    let realFields: [MappedField]
    let demo: MappedField
    @ObservedObject var store: FieldMappingStore
    @Binding var isShowingFieldList: Bool
    let handleSelectField: (UUID) -> Void
    let handleSelectDemo: () -> Void
    let prepareNewField: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kebun")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 8)
            VStack(spacing: 0) {
                ForEach(Array(FieldListPresentation.sortFields(realFields).prefix(2))) { field in
                    Button { handleSelectField(field.id) } label: {
                        FieldListCard(field: field, isActive: field.id == store.activeFieldID)
                            .padding(.horizontal, 18)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 84)
                }
                if realFields.isEmpty || store.isDemoSelected {
                    Button(action: handleSelectDemo) {
                        FieldListCard(field: demo, isActive: store.isDemoSelected)
                            .padding(.horizontal, 18)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 28, style: .continuous))

            HomeNavigationRow(title: "Tambah Kebun", symbol: "plus", action: prepareNewField)
            HomeNavigationRow(title: "Daftar Kebun", symbol: "map") {
                isShowingFieldList = true
            }
        }
        .padding(.top, 10)
    
    }

}

#if DEBUG
#Preview {
    @Previewable @State var showsList = false
    HomeFieldsSection(realFields: [PreviewFixtures.field], demo: PreviewFixtures.demo, store: PreviewFixtures.store(), isShowingFieldList: $showsList, handleSelectField: { _ in }, handleSelectDemo: {}, prepareNewField: {}).padding()
}
#endif
