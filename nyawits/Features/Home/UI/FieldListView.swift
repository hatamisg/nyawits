import SwiftUI

/// Aksi per kebun pada daftar; satu item presentasi dengan UUID target
/// (PLAN §4), bukan banyak boolean yang bisa terbuka bersamaan.
enum FieldListAction: Identifiable {
    case edit(UUID)
    case history(UUID)
    case delete(UUID)

    var id: UUID {
        switch self {
        case .edit(let id), .history(let id), .delete(let id): id
        }
    }
}

/// Permintaan hapus untuk confirmation dialog (UUID target + nama terbaru).
struct FieldDeleteRequest: Identifiable {
    let id: UUID
    let name: String
    let isActive: Bool
    let hasHistory: Bool
}

struct FieldListView: View {
    let onAddField: () -> Void
    /// Pilih kebun sebagai konteks aktif; root yang menutup daftar.
    let onSelectField: (UUID) -> Void
    var onSelectDemo: () -> Void = {}
    @State private var demo = NDREDemoFactory.makeField()
    /// Aksi awal untuk debug hook UI test (buka sheet/dialog langsung).
    var initialAction: FieldListAction?

    @EnvironmentObject private var store: FieldMappingStore
    @State private var searchText = ""
    @State private var presentation: FieldListAction?
    @State private var deleteRequest: FieldDeleteRequest?
    @State private var warningMessage: String?
    @State private var renameMismatchNotice: String?
    @State private var didApplyInitialAction = false

    private var realFields: [MappedField] {
        FieldListPresentation.filterRealFields(store.fields)
    }

    private var sortedRealFields: [MappedField] {
        FieldListPresentation.sortFields(realFields)
    }

    private var visibleFields: [MappedField] {
        FieldListPresentation.searchFields(sortedRealFields, query: searchText)
    }

    private var showsDemoResult: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !FieldListPresentation.searchFields([demo], query: searchText).isEmpty
    }

    var body: some View {
        List {
            if let error = store.lastErrorMessage {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 4)
                }
            }

            if realFields.isEmpty {
                Section {
                    emptyCollectionState
                }
                .listRowBackground(Color.clear)
            } else if visibleFields.isEmpty && !showsDemoResult {
                Section {
                    emptySearchResultState
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(visibleFields) { field in
                        fieldRow(field)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(countHeaderText)
                        Text("Pilih kebun untuk ditampilkan di Home")
                    }
                }
            }
            if showsDemoResult {
                Section {
                    Button(action: onSelectDemo) {
                        VStack(alignment: .leading, spacing: 3) {
                            FieldListCard(field: demo, isActive: store.isDemoSelected)
                            Text("SIMULASI · 200 tanaman contoh")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Tampilkan kebun simulasi di Home. Tidak mengubah data kebun Anda.")
                } header: {
                    Text("Kebun demo")
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Daftar Kebun")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Cari kebun")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAddField) {
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                }
                .accessibilityLabel("Tambah kebun")
            }
        }
        .sheet(item: $presentation) { action in
            switch action {
            case .edit(let id):
                editSheet(for: id)
            case .history(let id):
                historySheet(for: id)
            case .delete:
                EmptyView()
            }
        }
        .confirmationDialog(
            deleteRequest.map { "Hapus \($0.name)?" } ?? "Hapus kebun?",
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("Hapus", role: .destructive, action: performDelete)
            Button("Batal", role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
        .alert("Perhatian", isPresented: warningBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(warningMessage ?? "")
        }
        .alert("Nama diperbarui", isPresented: renameMismatchBinding) {
            Button("Hapus pencarian") { searchText = "" }
            Button("Biarkan", role: .cancel) {}
        } message: {
            Text(renameMismatchNotice ?? "Nama diperbarui. Kebun tidak cocok dengan pencarian saat ini.")
        }
        .onAppear {
            #if DEBUG
            applyInitialActionIfNeeded()
            #endif
        }
    }

    #if DEBUG
    private func applyInitialActionIfNeeded() {
        guard !didApplyInitialAction else { return }
        didApplyInitialAction = true
        switch initialAction {
        case .edit(let id):
            presentation = .edit(id)
        case .history(let id):
            presentation = .history(id)
        case .delete(let id):
            if let field = store.field(id: id) {
                deleteRequest = Self.buildDeleteRequest(for: field, activeID: store.activeFieldID)
            }
        case nil:
            break
        }
    }

    /// Pemetaan argumen launch debug ke aksi daftar (target: kebun aktif atau pertama).
    static func debugInitialAction(
        _ arguments: [String],
        store: FieldMappingStore
    ) -> FieldListAction? {
        let candidates = FieldListPresentation.sortFields(FieldListPresentation.filterRealFields(store.fields))
        if arguments.contains("-ui-test-open-edit"), let field = store.activeField ?? candidates.first {
            return .edit(field.id)
        }
        if arguments.contains("-ui-test-open-delete"), let field = store.activeField ?? candidates.first {
            return .delete(field.id)
        }
        if arguments.contains("-ui-test-open-history"),
           let field = candidates.first(where: { !($0.archivedMappings ?? []).isEmpty }) {
            return .history(field.id)
        }
        return nil
    }
    #endif

    // MARK: - Row

    /// Area select dan menu ellipsis adalah sibling (PLAN §5): menu tetap
    /// elemen tersendiri untuk VoiceOver dan tidak ada tombol bersarang.
    private func fieldRow(_ field: MappedField) -> some View {
        let archiveCount = field.archivedMappings?.count ?? 0
        return HStack(alignment: .center, spacing: 2) {
            Button {
                onSelectField(field.id)
            } label: {
                FieldListCard(field: field, isActive: field.id == store.activeFieldID)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Tampilkan di Home")

            Menu {
                Button {
                    presentation = .edit(field.id)
                } label: {
                    Label("Edit kebun", systemImage: "pencil")
                }
                if archiveCount > 0 {
                    Button {
                        presentation = .history(field.id)
                    } label: {
                        Label("Riwayat pemetaan (\(archiveCount))", systemImage: "clock.arrow.circlepath")
                    }
                }
                Button(role: .destructive) {
                    requestDelete(field)
                } label: {
                    Label("Hapus kebun", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Tindakan untuk \(field.name)")
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                requestDelete(field)
            } label: {
                Label("Hapus", systemImage: "trash")
            }
            .tint(.red)
            Button {
                presentation = .edit(field.id)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    // MARK: - Sheets & dialogs

    private func editSheet(for id: UUID) -> some View {
        Group {
            if let field = store.field(id: id) {
                FieldEditView(field: field) { updatedID, newName in
                    handleEditSaved(fieldID: updatedID, newName: newName)
                }
            } else {
                missingFieldView
            }
        }
    }

    private func historySheet(for id: UUID) -> some View {
        Group {
            if let field = store.field(id: id) {
                FieldMappingHistoryView(field: field)
            } else {
                missingFieldView
            }
        }
    }

    private var missingFieldView: some View {
        ContentUnavailableView(
            "Kebun tidak tersedia",
            systemImage: "questionmark.circle",
            description: Text("Kebun ini sudah tidak tersedia.")
        )
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { deleteRequest != nil },
            set: { if !$0 { deleteRequest = nil } }
        )
    }

    private var warningBinding: Binding<Bool> {
        Binding(
            get: { warningMessage != nil },
            set: { if !$0 { warningMessage = nil } }
        )
    }

    private var renameMismatchBinding: Binding<Bool> {
        Binding(
            get: { renameMismatchNotice != nil },
            set: { if !$0 { renameMismatchNotice = nil } }
        )
    }

    private var deleteMessage: String {
        guard let request = deleteRequest else { return "" }
        var message = "Pemetaan saat ini"
        if request.hasHistory { message += ", riwayat pemetaan" }
        message += ", dan foto lokal kebun ini akan dihapus dan tidak dapat dipulihkan melalui aplikasi."
        if request.isActive {
            message += " Home akan berpindah ke kebun lain atau menjadi kosong."
        }
        return message
    }

    private var countHeaderText: String {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return realFields.count == 1 ? "1 kebun" : "\(realFields.count) kebun"
        }
        return "Menampilkan \(visibleFields.count) dari \(realFields.count) kebun"
    }

    // MARK: - Actions

    private func requestDelete(_ field: MappedField) {
        // Resolve target terbaru saat dialog diminta (PLAN §4).
        guard let latest = store.field(id: field.id) else { return }
        deleteRequest = Self.buildDeleteRequest(for: latest, activeID: store.activeFieldID)
    }

    static func buildDeleteRequest(for field: MappedField, activeID: UUID?) -> FieldDeleteRequest {
        FieldDeleteRequest(
            id: field.id,
            name: field.name,
            isActive: field.id == activeID,
            hasHistory: !(field.archivedMappings ?? []).isEmpty
        )
    }

    private func performDelete() {
        guard let request = deleteRequest else { return }
        deleteRequest = nil
        switch store.deleteField(id: request.id) {
        case .success(let outcome):
            for warning in outcome.warnings {
                switch warning {
                case .photoCleanupIncomplete:
                    warningMessage = "Kebun dihapus, tetapi sebagian file foto belum dibersihkan."
                case .selectionRestoreFailed:
                    warningMessage = "Kebun terhapus, tetapi pemilihan kebun aktif belum tersimpan. Pilihan dipulihkan saat aplikasi dibuka lagi."
                }
            }
        case .failure:
            // Pesan tampil di Section error dari store; tetap di daftar.
            break
        }
    }

    /// Nama baru yang tidak cocok pencarian diberi tahu, query tidak dihapus diam-diam.
    private func handleEditSaved(fieldID: UUID, newName: String) {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        let matches = newName.range(of: trimmedQuery, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        guard !matches else { return }
        renameMismatchNotice = "Nama diperbarui. Kebun tidak cocok dengan pencarian saat ini."
    }

    private var emptyCollectionState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "map.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 6) {
                Text("Belum ada kebun")
                    .font(.title3.weight(.bold))
                Text("Buat batas kebun dan baris mulsa, lalu foto tanaman satu per satu.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onAddField) {
                Label("Tambah Kebun", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.green, in: Capsule())
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }

    private var emptySearchResultState: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("Kebun tidak ditemukan")
                    .font(.headline.weight(.semibold))
                Text("Coba nama lain atau hapus pencarian")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

struct FieldListView_Previews: PreviewProvider {
    static var previews: some View {
        let store = FieldMappingStore(
            storageRoot: FileManager.default.temporaryDirectory
                .appendingPathComponent("nyawits-preview-list-\(UUID().uuidString)", isDirectory: true)
        )
        NavigationStack {
            FieldListView(
                onAddField: {},
                onSelectField: { _ in },
                initialAction: nil
            )
        }
        .environmentObject(store)
    }
}
