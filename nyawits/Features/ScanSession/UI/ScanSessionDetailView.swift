import SwiftUI

/// Satu sesi: daftar petak yang terisi satu per satu, dan tombol tutup sesi.
///
/// Tidak ada layar "arahkan kamera, dapat jawaban". Sebelum sesi ditutup, petak
/// BELUM punya skor, dan layar ini mengatakannya begitu.
struct ScanSessionDetailView: View {
    let sessionID: UUID

    @EnvironmentObject private var scanStore: ScanSessionStore

    @State private var isAddingMeasurement = false
    @State private var isClosingSession = false
    @State private var sessionNote = ""
    @State private var notice: String?
    @State private var editingMeasurementID: UUID?

    private var session: ScanSession? { scanStore.session(id: sessionID) }

    private var ranking: SessionRanking? {
        guard case let .success(value)? = scanStore.ranking(for: sessionID) else { return nil }
        return value
    }

    private var rankingError: Error? {
        guard case let .failure(error)? = scanStore.ranking(for: sessionID) else { return nil }
        return error
    }

    var body: some View {
        Group {
            if let session {
                content(for: session)
            } else {
                ContentUnavailableView(
                    "Sesi tidak ditemukan",
                    systemImage: "questionmark.folder",
                    description: Text("Sesi ini sudah tidak tersedia.")
                )
            }
        }
        .navigationTitle(session.map { ScanSessionPresentation.sessionTitle($0) } ?? "Sesi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let session, !session.isClosed {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingMeasurement = true
                    } label: {
                        Label("Tambah petak", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingMeasurement) {
            PlantMeasurementEditorView(sessionID: sessionID)
                .environmentObject(scanStore)
        }
        .alert("Tutup sesi", isPresented: $isClosingSession) {
            TextField("Catatan lapangan (opsional)", text: $sessionNote)
            Button("Batal", role: .cancel) {}
            Button("Tutup sesi") { closeSession() }
        } message: {
            Text("Setelah ditutup, isi sesi tidak bisa diubah lagi dan peringkatnya muncul. Catat kondisi yang terlihat — kering, ternaungi, baru disiram — karena alat ini tidak bisa menyebut penyebab ketertinggalan.")
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

    @ViewBuilder
    private func content(for session: ScanSession) -> some View {
        List {
            statusSection(for: session)
            measurementSection(for: session)
            if session.isClosed {
                resultSection(for: session)
            } else {
                closeSection(for: session)
            }
        }
    }

    private func statusSection(for session: ScanSession) -> some View {
        Section {
            if session.isClosed {
                Label(ScanSessionPresentation.sessionStatusText(session), systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                if let note = session.note {
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Label(ScanSessionPresentation.sessionStatusText(session), systemImage: "record.circle")
                    .foregroundStyle(.orange)
                Text(ScanSessionPresentation.openSessionExplanation(session))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func measurementSection(for session: ScanSession) -> some View {
        Section("Petak") {
            let rows = ScanSessionPresentation.rows(for: session, ranking: ranking)
            if rows.isEmpty {
                Text("Belum ada petak. Tiap petak butuh tiga frame: 720 nm, 850 nm, dan RGB.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(rows) { row in
                MeasurementRowView(row: row)
                    .contentShape(Rectangle())
                    .swipeActions(edge: .trailing) {
                        if !session.isClosed {
                            Button(role: .destructive) {
                                remove(measurementID: row.measurementID)
                            } label: {
                                Label("Hapus", systemImage: "trash")
                            }
                        }
                    }
            }
        }
    }

    private func closeSection(for session: ScanSession) -> some View {
        Section {
            Button {
                sessionNote = session.note ?? ""
                isClosingSession = true
            } label: {
                Label("Tutup sesi dan lihat peringkat", systemImage: "flag.checkered")
            }
            .disabled(session.measurements.isEmpty)
        } footer: {
            if session.measurementCount < ScanSession.suggestedMinimumMeasurements,
               !session.measurements.isEmpty {
                Text("Sesi boleh ditutup sekarang, tapi dengan \(session.measurementCount) petak pembandingnya masih rapuh. Sekitar \(ScanSession.suggestedMinimumMeasurements) petak disarankan.")
            }
        }
    }

    @ViewBuilder
    private func resultSection(for session: ScanSession) -> some View {
        if let ranking {
            Section {
                NavigationLink {
                    ScanRankingView(sessionID: session.id)
                } label: {
                    Label("Lihat peringkat dan batasnya", systemImage: "list.number")
                }
                ForEach(ranking.warnings.indices, id: \.self) { index in
                    Label(
                        ScanSessionPresentation.warningText(ranking.warnings[index]),
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.orange)
                }
            }
        } else if let rankingError {
            Section {
                Label(message(for: rankingError), systemImage: "exclamationmark.octagon")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func message(for error: Error) -> String {
        if let error = error as? RankingError { return error.message }
        if let error = error as? VigorModelError { return error.message }
        if let error = error as? BundleJSONResource.LoadError { return error.message }
        return "Peringkat tidak dapat dihitung."
    }

    private func remove(measurementID: UUID) {
        if case let .failure(error) = scanStore.removeMeasurement(id: measurementID, from: sessionID) {
            notice = error.message
        }
    }

    private func closeSession() {
        if case let .failure(error) = scanStore.closeSession(id: sessionID, note: sessionNote) {
            notice = error.message
        }
    }
}

/// Satu baris petak. Selama sesi belum ditutup, kolom skor berisi kalimat yang
/// menjelaskan kenapa belum ada skor — bukan nol dan bukan tanda hubung.
struct MeasurementRowView: View {
    let row: MeasurementRow

    var body: some View {
        HStack(spacing: 12) {
            if let position = row.palettePosition {
                Circle()
                    .fill(NDREPalette.color(position))
                    .frame(width: 16, height: 16)
            } else {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 16, height: 16)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title).font(.body)
                Text(row.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if let priority = row.visitPriority, let standing = row.standing {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("#\(priority)")
                        .font(.headline.monospacedDigit())
                    Text(standing.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Belum ada skor")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
