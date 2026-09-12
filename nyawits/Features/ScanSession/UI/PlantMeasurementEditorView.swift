import SwiftUI
import UniformTypeIdentifiers

/// Satu petak: tiga frame, dua kotak ROI per frame, lalu simpan sepuluh DN mentah.
struct PlantMeasurementEditorView: View {
    let sessionID: UUID

    @EnvironmentObject private var scanStore: ScanSessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var frames: [FrameRole: ImportedFrame] = [:]
    @State private var regions: [FrameRole: ROIRegion] = [:]
    @State private var importingRole: FrameRole?
    @State private var pickingROIFor: FrameRole?
    @State private var label = ""
    @State private var fieldNote = ""
    @State private var notice: String?
    @State private var isSaving = false

    private let sampler = RawFrameSampler()

    /// Sepasang kotak yang melayani seluruh band satu frame.
    struct ROIRegion: Equatable {
        var canopy: ROIRect
        var card: ROIRect
    }

    private var source: FileImportFrameSource { FileImportFrameSource(store: scanStore) }

    private var premiseIssues: [FramePremiseIssue] {
        FramePremise.issues(for: FrameRole.allCases.compactMap { frames[$0] })
    }

    private var isComplete: Bool {
        FrameRole.allCases.allSatisfy { frames[$0] != nil && regions[$0] != nil }
    }

    private var isBlocked: Bool {
        premiseIssues.contains(where: \.blocksCalculation)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(FrameRole.allCases) { role in
                        frameRow(role)
                    }
                } header: {
                    Text("Tiga frame")
                } footer: {
                    Text("Kartu abu-abu wajib terlihat di KETIGA frame — bukan difoto terpisah. Kanopi dan kartu harus terkena cahaya yang sama supaya drift iluminasi batal saat dibagi.")
                }

                if !premiseIssues.isEmpty {
                    Section("Premis pengukuran") {
                        ForEach(premiseIssues.indices, id: \.self) { index in
                            let issue = premiseIssues[index]
                            Label(issue.message, systemImage: issue.blocksCalculation
                                  ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(issue.blocksCalculation ? .red : .orange)
                        }
                    }
                }

                Section("Keterangan petak") {
                    TextField("Nama petak (contoh: baris 3 tanaman 7)", text: $label)
                    TextField("Catatan lapangan: kering? ternaungi? baru disiram?",
                              text: $fieldNote, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Petak baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { discardAndDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                        .disabled(!isComplete || isBlocked || isSaving)
                }
            }
            .fileImporter(
                isPresented: Binding(
                    get: { importingRole != nil },
                    set: { if !$0 { importingRole = nil } }
                ),
                allowedContentTypes: [.rawImage, .image],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .sheet(item: $pickingROIFor) { role in
                if let frame = frames[role], let url = scanStore.frameURL(filename: frame.filename) {
                    ROIPickerView(
                        frame: frame,
                        frameURL: url,
                        initialCanopy: regions[role]?.canopy,
                        initialCard: regions[role]?.card
                    ) { canopy, card in
                        regions[role] = ROIRegion(canopy: canopy, card: card)
                    }
                }
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
    }

    private func frameRow(_ role: FrameRole) -> some View {
        HStack(spacing: 12) {
            Image(systemName: frames[role] == nil ? "circle.dashed" :
                    (regions[role] == nil ? "circle.lefthalf.filled" : "checkmark.circle.fill"))
                .foregroundStyle(regions[role] == nil ? Color.secondary : Color.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(role.title).font(.body)
                Text(frameStatus(role))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if frames[role] == nil {
                Button("Pilih") { importingRole = role }
                    .buttonStyle(.bordered)
            } else {
                Button(regions[role] == nil ? "Tandai ROI" : "Ubah ROI") { pickingROIFor = role }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 2)
    }

    private func frameStatus(_ role: FrameRole) -> String {
        guard let frame = frames[role] else {
            return "Belum ada berkas · menyumbang \(role.bands.count) entri band"
        }
        if regions[role] == nil {
            return "Berkas .\(frame.sourceFormat) siap · ROI belum ditandai"
        }
        return "Berkas .\(frame.sourceFormat) · kanopi dan kartu sudah ditandai"
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard let role = importingRole else { return }
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            do {
                let frame = try source.adopt(fileAt: url, as: role)
                // Mengganti berkas membatalkan ROI lama: koordinatnya milik frame itu.
                if let previous = frames[role], previous.filename != frame.filename {
                    scanStore.deleteFrame(filename: previous.filename)
                    regions[role] = nil
                }
                frames[role] = frame
                pickingROIFor = role
            } catch let error as FrameImportError {
                notice = error.message
            } catch {
                notice = "Frame tidak dapat diimpor."
            }
        case let .failure(error):
            notice = error.localizedDescription
        }
    }

    private func save() {
        guard !isBlocked else { return }
        isSaving = true
        defer { isSaving = false }

        var bands: [BandReading] = []
        for role in FrameRole.allCases {
            guard let frame = frames[role],
                  let region = regions[role],
                  let url = scanStore.frameURL(filename: frame.filename) else {
                notice = "Frame \(role.title) belum lengkap."
                return
            }
            do {
                bands.append(contentsOf: try sampler.readings(
                    frame: frame,
                    frameURL: url,
                    canopy: region.canopy,
                    card: region.card
                ))
            } catch let error as RawFrameSampler.SamplerError {
                notice = "\(role.title): \(error.message)"
                return
            } catch {
                notice = "\(role.title): frame tidak dapat diukur."
                return
            }
        }

        var measurement = PlantMeasurement(bands: bands)
        measurement.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        measurement.fieldNote = fieldNote.trimmingCharacters(in: .whitespacesAndNewlines)
        measurement.rawFormat = frames[.rgb]?.sourceFormat
        measurement.whiteBalanceLocked = premiseIssues.contains(.whiteBalanceUnknown)
            ? nil
            : !premiseIssues.contains(.whiteBalanceVaries)

        // Tolak lebih dulu daripada menyimpan angka yang tidak bisa dihitung.
        if case let .failure(reason) = MeasurementCalculator.quantities(for: measurement) {
            notice = reason.message
            return
        }

        switch scanStore.addMeasurement(measurement, to: sessionID) {
        case .success:
            dismiss()
        case let .failure(error):
            notice = error.message
        }
    }

    /// Frame yang sudah disalin tapi petaknya dibatalkan tidak boleh tertinggal.
    private func discardAndDismiss() {
        for frame in frames.values {
            scanStore.deleteFrame(filename: frame.filename)
        }
        dismiss()
    }
}
