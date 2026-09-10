import SwiftUI

struct FieldDetailView: View {
    let fieldID: UUID
    let onResumeField: (MappedField) -> Void

    @EnvironmentObject private var store: FieldMappingStore

    var body: some View {
        Group {
            if let field = store.field(id: fieldID) {
                ScrollView {
                    FieldMappingCard(field: field) {
                        onResumeField(field)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle(field.name)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                fieldNotFoundView
            }
        }
    }

    private var fieldNotFoundView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Kebun tidak tersedia")
                .font(.headline)
            Text("Data kebun ini mungkin telah dihapus atau tidak dapat dimuat.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Kebun")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Previews

struct FieldDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let store = FieldMappingStore()
        let demo = NDREDemoFactory.makeField()
        NavigationStack {
            FieldDetailView(fieldID: demo.id, onResumeField: { _ in })
        }
        .environmentObject(store)
    }
}
