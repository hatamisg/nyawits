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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    @State private var demo = NDREDemoFactory.makeField()
    @State private var isShowingFieldList = false
    @State private var isShowingKropsMenu = false
    @State private var titleFrame: CGRect = .zero
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
                LazyVStack(spacing: 18) {
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
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .accessibilityHidden(isShowingKropsMenu)
            .background(Color(uiColor: .systemGroupedBackground))
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
            .navigationTitle(effectiveTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $isShowingFieldList) {
                FieldListView(
                    onAddField: prepareNewField,
                    onSelectField: handleSelectField,
                    onSelectDemo: handleSelectDemo,
                    initialAction: pendingListAction
                )
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button(action: toggleMenu) {
                        HStack(spacing: 5) {
                            Text(effectiveTitleText)
                                .font(AveriaFont.bold(size: effectiveTitleFontSize))
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: max(11, effectiveTitleFontSize * 0.55), weight: .semibold))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(isShowingKropsMenu ? 180 : 0))
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: KropsTitleFramePreferenceKey.self,
                                value: geo.frame(in: .global)
                            )
                        }
                    )
                    .accessibilityLabel("Menu kebun")
                    .accessibilityValue(isShowingKropsMenu ? "Terbuka" : "Tertutup")
                }
            }
        }
        .onPreferenceChange(KropsTitleFramePreferenceKey.self) { frame in
            if frame != .zero {
                titleFrame = frame
            }
        }
        .overlay {
            if isShowingKropsMenu {
                GeometryReader { proxy in
                    ZStack(alignment: .top) {
                        // Backdrop penutup tap di luar panel (tidak meneruskan tap ke peta/kamera)
                        Color.clear
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                closeMenu()
                            }

                        // Area penangkap tap di atas tombol judul agar tap Krops menutup panel
                        Button(action: closeMenu) {
                            Color.clear
                                .frame(
                                    width: max(titleFrame.width + 16, 44),
                                    height: max(titleFrame.height, 44)
                                )
                                .contentShape(Rectangle())
                        }
                        .position(
                            x: titleFrame.midX > 0 ? titleFrame.midX : proxy.size.width / 2,
                            y: titleFrame.midY > 0 ? titleFrame.midY : 64
                        )
                        .accessibilityHidden(true)

                        // Panel dropdown ditambatkan tepat 8pt di bawah batas bawah judul
                        VStack(spacing: 0) {
                            KropsMenuPanel(
                                onSelectList: {
                                    closeMenu()
                                    isShowingFieldList = true
                                },
                                onSelectAdd: {
                                    closeMenu()
                                    prepareNewField()
                                },
                                availableWidth: proxy.size.width - 32
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, titleFrame.maxY > 0 ? titleFrame.maxY + 8 : 100)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                                    removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                                )
                        )
                    }
                    .ignoresSafeArea()
                    .accessibilityAction(.escape) {
                        closeMenu()
                    }
                }
            }
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-ui-test-open-menu") {
                isShowingKropsMenu = true
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

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 92, height: 92)
                Image(systemName: "map.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 7) {
                Text("Belum ada kebun")
                    .font(.title3.weight(.bold))
                Text("Buat batas kebun dan baris mulsa, lalu foto tanaman satu per satu.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: prepareNewField) {
                Label("Petakan Kebun", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.green, in: Capsule())
            }

            if !store.isDemoSelected {
                Button("Lihat demo") {
                    handleSelectDemo()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(24)
        .background(.background, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.top, 28)
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

    private func toggleMenu() {
        if reduceMotion {
            isShowingKropsMenu.toggle()
        } else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                isShowingKropsMenu.toggle()
            }
        }
    }

    private func closeMenu() {
        if reduceMotion {
            isShowingKropsMenu = false
        } else {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                isShowingKropsMenu = false
            }
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
