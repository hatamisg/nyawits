import Combine
import Foundation

/// State sesi pindai. Sejajar dengan `FieldMappingStore` dan memakai pola
/// transaksi yang sama: susun kandidat -> tulis atomik -> baru publish.
@MainActor
final class ScanSessionStore: ObservableObject {
    @Published private(set) var sessions: [ScanSession] = []
    @Published private(set) var lastErrorMessage: String?

    private let repository: any ScanSessionRepository

    /// True saat `scan-sessions.json` gagal dimuat: mutasi yang bisa menimpa
    /// berkas dengan array kosong diblokir sampai kondisinya diselesaikan.
    private(set) var dataLoadFailed = false

    /// Model dibaca sekali dan hasilnya disimpan apa adanya — termasuk
    /// kegagalannya, supaya pesan yang sama muncul konsisten alih-alih
    /// dibaca ulang tiap kali peringkat diminta.
    private lazy var modelResult: Result<VigorModel, Error> = {
        do {
            return .success(try VigorModel.loadFromBundle())
        } catch {
            return .failure(error)
        }
    }()

    init(repository: any ScanSessionRepository) {
        self.repository = repository
        do {
            try repository.prepare()
            load()
        } catch {
            lastErrorMessage = "Data sesi pindai tidak dapat dibuka."
            dataLoadFailed = true
        }
    }

    // MARK: - Queries

    func session(id: UUID) -> ScanSession? {
        sessions.first(where: { $0.id == id })
    }

    func sessions(forField fieldID: UUID) -> [ScanSession] {
        sessions.filter { $0.fieldID == fieldID }
    }

    /// Sesi yang masih terbuka untuk satu kebun, kalau ada. Maksimal satu.
    func openSession(forField fieldID: UUID) -> ScanSession? {
        sessions.first(where: { $0.fieldID == fieldID && !$0.isClosed })
    }

    func measurement(id: UUID, in sessionID: UUID) -> PlantMeasurement? {
        session(id: sessionID)?.measurements.first(where: { $0.id == id })
    }

    // MARK: - Peringkat

    /// Peringkat satu sesi, dihitung ULANG dari DN mentah tiap kali diminta.
    ///
    /// Turunan sengaja tidak pernah dibaca dari disk: perubahan koefisien harus
    /// langsung tercermin di sesi lama. Mengembalikan `nil` kalau sesinya tidak
    /// ada, dan `.failure` kalau sesi belum ditutup atau modelnya tidak terbaca —
    /// bukan angka nol yang tampak sah.
    func ranking(for sessionID: UUID) -> Result<SessionRanking, Error>? {
        guard let session = session(id: sessionID) else { return nil }
        // Diperiksa sebelum model dibaca: "sesi belum ditutup" adalah kondisi
        // yang lebih spesifik dan lebih sering, jadi pesannya tidak boleh
        // tertutup oleh kegagalan membaca berkas model.
        guard session.isClosed else { return .failure(RankingError.sessionNotClosed) }
        switch modelResult {
        case let .failure(error):
            return .failure(error)
        case let .success(model):
            do {
                return .success(try MeasurementCalculator.rank(session: session, model: model))
            } catch {
                return .failure(error)
            }
        }
    }

    /// Model untuk layar hasil: peringatan dan status validasi dibaca dari JSON,
    /// bukan ditulis ulang sebagai string Swift.
    var vigorModel: Result<VigorModel, Error> { modelResult }

    // MARK: - Mutasi

    @discardableResult
    func openSession(fieldID: UUID, label: String? = nil) -> Result<UUID, ScanSessionStoreError> {
        guard !dataLoadFailed else { return .failure(.dataLoadFailed) }
        guard openSession(forField: fieldID) == nil else { return .failure(.duplicateOpenSession) }

        var session = ScanSession(fieldID: fieldID)
        session.label = normalized(label)

        var candidates = sessions
        candidates.append(session)
        candidates.sort { $0.openedAt > $1.openedAt }
        guard persist(candidates) else { return .failure(.storageFailure) }
        sessions = candidates
        return .success(session.id)
    }

    @discardableResult
    func addMeasurement(
        _ measurement: PlantMeasurement,
        to sessionID: UUID
    ) -> Result<Void, ScanSessionStoreError> {
        guard !dataLoadFailed else { return .failure(.dataLoadFailed) }
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return .failure(.sessionNotFound)
        }
        guard !sessions[index].isClosed else { return .failure(.sessionClosed) }

        var candidates = sessions
        candidates[index].measurements.append(measurement)
        guard persist(candidates) else { return .failure(.storageFailure) }
        sessions = candidates
        return .success(())
    }

    @discardableResult
    func updateMeasurement(
        _ measurement: PlantMeasurement,
        in sessionID: UUID
    ) -> Result<Void, ScanSessionStoreError> {
        guard !dataLoadFailed else { return .failure(.dataLoadFailed) }
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return .failure(.sessionNotFound)
        }
        guard !sessions[sessionIndex].isClosed else { return .failure(.sessionClosed) }
        guard let measurementIndex = sessions[sessionIndex].measurements
            .firstIndex(where: { $0.id == measurement.id }) else {
            return .failure(.measurementNotFound)
        }
        guard sessions[sessionIndex].measurements[measurementIndex] != measurement else {
            return .success(())
        }

        var candidates = sessions
        candidates[sessionIndex].measurements[measurementIndex] = measurement
        guard persist(candidates) else { return .failure(.storageFailure) }
        sessions = candidates
        return .success(())
    }

    /// Hapus satu petak. Berkas frame-nya dihapus hanya setelah metadata
    /// tersimpan — metadata adalah sumber kebenaran, jadi berkas yatim
    /// sementara masih bisa diterima tapi rujukan menggantung tidak.
    @discardableResult
    func removeMeasurement(
        id measurementID: UUID,
        from sessionID: UUID
    ) -> Result<Void, ScanSessionStoreError> {
        guard !dataLoadFailed else { return .failure(.dataLoadFailed) }
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return .failure(.sessionNotFound)
        }
        guard !sessions[sessionIndex].isClosed else { return .failure(.sessionClosed) }
        guard let measurement = sessions[sessionIndex].measurements
            .first(where: { $0.id == measurementID }) else {
            return .failure(.measurementNotFound)
        }

        var candidates = sessions
        candidates[sessionIndex].measurements.removeAll { $0.id == measurementID }
        guard persist(candidates) else { return .failure(.storageFailure) }
        sessions = candidates

        for filename in orphanedFrames(of: measurement) {
            _ = repository.deleteFrame(named: filename)
        }
        return .success(())
    }

    /// Tutup sesi. Setelah ini — dan hanya setelah ini — peringkat bisa dihitung.
    @discardableResult
    func closeSession(
        id sessionID: UUID,
        note: String? = nil
    ) -> Result<Void, ScanSessionStoreError> {
        guard !dataLoadFailed else { return .failure(.dataLoadFailed) }
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return .failure(.sessionNotFound)
        }
        guard !sessions[index].isClosed else { return .failure(.sessionAlreadyClosed) }
        guard !sessions[index].measurements.isEmpty else { return .failure(.emptySession) }

        var candidates = sessions
        candidates[index].closedAt = Date()
        candidates[index].note = normalized(note)
        guard persist(candidates) else { return .failure(.storageFailure) }
        sessions = candidates
        return .success(())
    }

    @discardableResult
    func deleteSession(id sessionID: UUID) -> Result<ScanSessionDeleteOutcome, ScanSessionStoreError> {
        guard !dataLoadFailed else { return .failure(.dataLoadFailed) }
        guard let session = session(id: sessionID) else { return .failure(.sessionNotFound) }

        var candidates = sessions
        candidates.removeAll { $0.id == sessionID }
        guard persist(candidates) else { return .failure(.storageFailure) }
        sessions = candidates

        var outcome = ScanSessionDeleteOutcome()
        let remaining = referencedFrames(in: candidates)
        for filename in frameFilenames(of: session) where !remaining.contains(filename) {
            if !repository.deleteFrame(named: filename) {
                outcome.warnings = [.frameCleanupIncomplete]
            }
        }
        return .success(outcome)
    }

    // MARK: - Frame

    /// Simpan frame mentah lebih dulu, baru metadatanya — nama berkas diturunkan
    /// dari ID, jadi ID harus ada sebelum byte-nya ditulis.
    func saveFrame(_ data: Data, frameID: UUID, pathExtension: String) -> String? {
        do {
            return try repository.saveFrame(data, frameID: frameID, pathExtension: pathExtension)
        } catch {
            lastErrorMessage = "Frame tidak dapat disimpan. Periksa ruang penyimpanan lalu coba lagi."
            return nil
        }
    }

    func deleteFrame(filename: String?) {
        guard let filename else { return }
        _ = repository.deleteFrame(named: filename)
    }

    func frameURL(filename: String?) -> URL? {
        guard let filename else { return nil }
        return repository.frameURL(filename: filename)
    }

    // MARK: - Private

    private func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func frameFilenames(of session: ScanSession) -> Set<String> {
        Set(session.measurements.flatMap { $0.bands.map(\.frameFilename) })
    }

    private func referencedFrames(in sessions: [ScanSession]) -> Set<String> {
        sessions.reduce(into: Set<String>()) { $0.formUnion(frameFilenames(of: $1)) }
    }

    /// Frame satu petak yang tidak dirujuk petak mana pun lagi.
    private func orphanedFrames(of measurement: PlantMeasurement) -> Set<String> {
        let referenced = referencedFrames(in: sessions)
        return Set(measurement.bands.map(\.frameFilename)).subtracting(referenced)
    }

    private func load() {
        do {
            sessions = try repository.loadSessions().sorted { $0.openedAt > $1.openedAt }
        } catch {
            lastErrorMessage = "Data sesi pindai rusak dan tidak dapat dimuat."
            dataLoadFailed = true
        }
    }

    /// Tulis kandidat secara atomik tanpa mengubah state in-memory.
    private func persist(_ candidates: [ScanSession]) -> Bool {
        do {
            try repository.saveSessions(candidates)
            lastErrorMessage = nil
            return true
        } catch {
            lastErrorMessage = "Perubahan belum tersimpan. Periksa ruang penyimpanan lalu coba lagi."
            return false
        }
    }
}
