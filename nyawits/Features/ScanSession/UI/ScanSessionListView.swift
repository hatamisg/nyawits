import SwiftUI

/// Daftar sesi pindai satu kebun, dan pintu membuka sesi baru.
struct ScanSessionListView: View {
    let fieldID: UUID?
    let fieldName: String?
    /// True saat layar ini muncul sebagai sheet, bukan didorong dari NavigationStack.
    var showsCloseButton = false

    @EnvironmentObject private var scanStore: ScanSessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var openedSessionID: UUID?
    @State private var notice: String?

    private var sessions: [ScanSession] {
        guard let fieldID else { return [] }
        return ScanSessionPresentation.sortSessions(scanStore.sessions(forField: fieldID))
    }

    var body: some View {
        List {
            if fieldID == nil {
                Section {
                    Text("Pilih kebun nyata lebih dulu. Sesi pindai selalu milik satu kebun, karena skornya dibandingkan di dalam kebun itu sendiri.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                explanationSection
                if sessions.isEmpty {
                    Section {
                        Text("Belum ada sesi pindai untuk kebun ini.")
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(sessions) { session in
                    Section {
                        NavigationLink {
                            ScanSessionDetailView(sessionID: session.id)
                        } label: {
                            row(for: session)
                        }
                    }
                }
            }
        }
        .navigationTitle("Sesi Pindai")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
            if let fieldID {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        openSession(fieldID: fieldID)
                    } label: {
                        Label("Buka sesi", systemImage: "plus")
                    }
                }
            }
        }
        .navigationDestination(item: $openedSessionID) { sessionID in
            ScanSessionDetailView(sessionID: sessionID)
        }
        .alert("Perhatian", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(notice ?? "")
        }
    }

    private var explanationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(fieldName ?? "Kebun aktif")
                    .font(.headline)
                Text("Satu sesi = satu kunjungan memindai kebun ini. Peringkat muncul setelah sesi ditutup, karena tiap petak dibandingkan terhadap petak terbaik di sesi yang sama.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func row(for session: ScanSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ScanSessionPresentation.sessionTitle(session))
                .font(.body.weight(.medium))
            HStack(spacing: 6) {
                Image(systemName: session.isClosed ? "checkmark.seal" : "record.circle")
                    .font(.caption)
                    .foregroundStyle(session.isClosed ? .green : .orange)
                Text(ScanSessionPresentation.sessionStatusText(session))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func openSession(fieldID: UUID) {
        switch scanStore.openSession(fieldID: fieldID) {
        case let .success(sessionID):
            openedSessionID = sessionID
        case let .failure(error):
            if error == .duplicateOpenSession,
               let existing = scanStore.openSession(forField: fieldID) {
                openedSessionID = existing.id
            } else {
                notice = error.message
            }
        }
    }
}
