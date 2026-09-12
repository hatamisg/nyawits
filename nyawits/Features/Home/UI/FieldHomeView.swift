import SwiftUI

struct FieldHomeView: View {
    /// Permintaan flow create; item-driven agar fieldID/name satu kesatuan
    /// dan dismissal bisa diverifikasi lewat ID committed di store.
    private struct CreateFieldFlow: Identifiable {
        let fieldID: UUID
        let name: String
        var id: UUID { fieldID }
    }

    @EnvironmentObject private var store: FieldMappingStore

    @Environment(\.kropsTitleFontSize) private var envTitleFontSize
    @Environment(\.kropsTitleText) private var envTitleText

    var titleFontSize: CGFloat?
    var titleText: String?

    init(titleFontSize: CGFloat? = nil, titleText: String? = nil) {
        self.titleFontSize = titleFontSize
        self.titleText = titleText
    }

    private var effectiveTitleFontSize: CGFloat {
        titleFontSize ?? envTitleFontSize
    }

    private var effectiveTitleText: String {
        titleText ?? envTitleText
    }

    @State private var newFieldName = ""
    @State private var newFieldID = UUID()
    @State private var isNamingField = FieldHomeView.initiallyOpensAddPanel
    @State private var createFlow: CreateFieldFlow?
    @State private var pendingCreatedFieldID: UUID?
    @State private var fieldToResume: MappedField?
    @State private var demo = VigorDemoFactory.makeField()
    @State private var isShowingFieldList = false
    @State private var isShowingHomeNotice = false
    @State private var homeNotice = ""
    @State private var pendingListAction: FieldListAction?

    private var realFields: [MappedField] {
        FieldListPresentation.filterRealFields(store.fields)
    }

    #if DEBUG
    private static let initiallyOpensAddPanel = UserDefaults.standard.bool(forKey: "UI_TEST_OPEN_ADD")
    #else
    private static let initiallyOpensAddPanel = false
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    homeHeader

                    VStack(spacing: 12) {
                        FertilizationFeature(fieldID: store.activeFieldID, isDemo: store.isDemoSelected)
                        FieldActionsFeature(fieldID: store.activeFieldID, isDemo: store.isDemoSelected)
                    }
                    Text("Heatmap")
                        .font(.title3.weight(.regular))

                        .accessibilityAddTraits(.isHeader)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    if store.isDemoSelected {
                        FieldMappingCard(field: demo, onContinue: {})
                            .id(demo.id)
                    } else if let field = store.activeField {
                        // Identitas per kebun: state kartu (foto terpilih dsb.) tidak ikut ke kebun lain.
                        FieldMappingCard(field: field) {
                            handleResume(field: field)
                        }
                        .id(field.id)
                    } else {
                        emptyState

                    }
                    fieldSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(Color.nyawitsHomeBackground.ignoresSafeArea())
            .alert("Nama kebun", isPresented: $isNamingField) {
                TextField("Contoh: Kebun Cabai Utara", text: $newFieldName)
                Button("Batal", role: .cancel) {}
                Button("Lanjut") {
                    let trimmedName = newFieldName.trimmingCharacters(in: .whitespacesAndNewlines)
                    newFieldName = trimmedName.isEmpty ? store.suggestedFieldName() : trimmedName
                    startCreateFlow()
                }
            } message: {
                Text("Nama ini dipakai untuk mengenali hasil pemetaan foto.")
            }
            .alert("Perhatian", isPresented: $isShowingHomeNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(homeNotice)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isShowingFieldList) {
                FieldListView(
                    onAddField: prepareNewField,
                    onSelectField: handleSelectField,
                    onSelectDemo: handleSelectDemo,
                    initialAction: pendingListAction
                )
                .toolbar(.visible, for: .navigationBar)
            }
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-ui-test-open-menu") {
                isShowingFieldList = true
            } else if ProcessInfo.processInfo.arguments.contains("-ui-test-open-list") {
                isShowingFieldList = true
            } else if ProcessInfo.processInfo.arguments.contains("-ui-test-open-add") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    prepareNewField()
                }
            } else if let action = FieldListView.debugInitialAction(
                ProcessInfo.processInfo.arguments, store: store) {
                pendingListAction = action
                isShowingFieldList = true
            }
            #endif
        }
        .fullScreenCover(item: $createFlow, onDismiss: handleCreateFlowDismissed) { flow in
            MappingFlowView(fieldID: flow.fieldID, fieldName: flow.name)
                .environmentObject(store)
        }
        .fullScreenCover(item: $fieldToResume) { field in
            PlantCaptureView(
                fieldID: field.id,
                fieldName: field.name,
                plan: field.plan,
                existingField: field,
                onFinished: { fieldToResume = nil }
            )
            .environmentObject(store)
        }
    }

    private var homeHeader: some View {
        HomeHeader(effectiveTitleText: effectiveTitleText, effectiveTitleFontSize: effectiveTitleFontSize)
    }

    private var fieldSection: some View {
        HomeFieldsSection(realFields: realFields, demo: demo, store: store, isShowingFieldList: $isShowingFieldList, handleSelectField: handleSelectField, handleSelectDemo: handleSelectDemo, prepareNewField: prepareNewField)
    }

    private var emptyState: some View {
        HomeEmptyState(store: store, prepareNewField: prepareNewField, handleSelectDemo: handleSelectDemo)
    }

    private func prepareNewField() {
        newFieldID = UUID()
        newFieldName = store.suggestedFieldName()
        isNamingField = true
    }

    private func startCreateFlow() {
        pendingCreatedFieldID = newFieldID
        createFlow = CreateFieldFlow(fieldID: newFieldID, name: newFieldName)
    }

    /// Setelah flow create ditutup: aktivasi hanya jika record benar-benar
    /// tersimpan (draft tersimpan diakui; batal sebelum save mempertahankan asal).
    private func handleCreateFlowDismissed() {
        guard let pendingID = pendingCreatedFieldID else { return }
        pendingCreatedFieldID = nil
        guard let created = store.field(id: pendingID), created.isDemo != true else { return }
        switch store.selectField(id: created.id) {
        case .success:
            // Tutup daftar bila create dimulai dari daftar; Home menampilkan kebun baru.
            isShowingFieldList = false
        case .failure(let error):
            isShowingHomeNotice = true
            homeNotice = Self.createActivationMessage(for: error)
        }
    }

    /// Pilih kebun dari daftar: tutup daftar pada sukses; gagal tetap di daftar
    /// dengan pesan dari store.
    private func handleSelectField(_ id: UUID) {
        if case .success = store.selectField(id: id) {
            isShowingFieldList = false
        } else if !isShowingFieldList {
            homeNotice = store.lastErrorMessage ?? "Kebun belum bisa dipilih. Coba lagi."
            isShowingHomeNotice = true
        }
    }

    private func handleSelectDemo() {
        if case .success = store.selectDemo() {
            isShowingFieldList = false
        } else if !isShowingFieldList {
            homeNotice = store.lastErrorMessage ?? "Demo belum bisa dipilih. Coba lagi."
            isShowingHomeNotice = true
        }
    }

    /// Resume hanya dengan record terbaru dari store; field terhapus tidak
    /// dibuka dengan snapshot lama.
    private func handleResume(field: MappedField) {
        guard let freshField = store.field(id: field.id), freshField.isDemo != true else {
            isShowingHomeNotice = true
            homeNotice = "Kebun ini sudah tidak tersedia. Pilih kebun lain dari daftar."
            return
        }
        fieldToResume = freshField
    }

    private static func createActivationMessage(for error: FieldStoreError) -> String {
        switch error {
        case .storageFailure:
            "Kebun sudah tersimpan, tetapi pemilihan belum berhasil. Coba pilih kebunnya dari Daftar Kebun."
        case .dataLoadFailed:
            "Data kebun gagal dimuat, sehingga pemilihan belum berhasil. Periksa data lalu coba lagi."
        case .fieldNotFound:
            "Kebun baru belum terdaftar. Buka Daftar Kebun untuk memilihnya."
        case .invalidName, .invalidPlan, .revisionStale, .captureStale:
            "Kebun sudah tersimpan, tetapi pemilihan belum berhasil. Coba pilih dari Daftar Kebun."
        }
    }


}

// MARK: - Previews

struct FieldHomeView_Previews: PreviewProvider {
    static var previews: some View {
        let store = FieldMappingStore(
            storageRoot: FileManager.default.temporaryDirectory
                .appendingPathComponent("nyawits-preview-home-\(UUID().uuidString)", isDirectory: true)
        )
        FieldHomeView()
            .environmentObject(store)
    }
}
