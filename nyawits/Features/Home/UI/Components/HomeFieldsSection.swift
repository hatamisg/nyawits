import SwiftUI
import UIKit

struct HomeFieldsSection: View {
    let realFields: [MappedField]
    let demo: MappedField
    @ObservedObject var store: FieldMappingStore
    @Binding var isShowingFieldList: Bool
    @Binding var isShowingScanSessions: Bool
    @Binding var isShowingSchedule: Bool
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
            HomeNavigationRow(title: "Sesi Pindai", symbol: "viewfinder") {
                isShowingScanSessions = true
            }
            HomeNavigationRow(title: "Jadwal Pemupukan", symbol: "calendar.badge.clock") {
                isShowingSchedule = true
            }
        }
        .padding(.top, 10)
    
    }

}
