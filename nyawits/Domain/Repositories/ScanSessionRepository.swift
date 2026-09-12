import Foundation

nonisolated enum ScanSessionStoreError: Equatable, Error {
    case sessionNotFound
    case measurementNotFound
    /// Sesi sudah ditutup: pengukuran tidak boleh ditambah atau diubah lagi,
    /// karena p90 sudah dihitung atas himpunan petak yang itu.
    case sessionClosed
    case sessionAlreadyClosed
    /// Menutup sesi kosong tidak ada gunanya: tidak ada yang bisa diperingkat.
    case emptySession
    /// Satu kebun hanya boleh punya satu sesi terbuka pada satu waktu.
    case duplicateOpenSession
    case storageFailure
    case dataLoadFailed

    var message: String {
        switch self {
        case .sessionNotFound:
            "Sesi ini sudah tidak tersedia. Perbarui daftar lalu pilih kembali."
        case .measurementNotFound:
            "Petak ini sudah tidak ada di sesi."
        case .sessionClosed:
            "Sesi sudah ditutup. Peringkatnya dihitung dari petak yang ada saat itu, jadi isinya tidak bisa diubah lagi."
        case .sessionAlreadyClosed:
            "Sesi ini sudah ditutup sebelumnya."
        case .emptySession:
            "Sesi belum berisi satu petak pun, jadi belum ada yang bisa diperingkat."
        case .duplicateOpenSession:
            "Kebun ini masih punya sesi yang terbuka. Tutup sesi itu dulu sebelum membuka yang baru."
        case .storageFailure:
            "Perubahan belum tersimpan. Periksa ruang penyimpanan lalu coba lagi."
        case .dataLoadFailed:
            "Data sesi yang tersimpan tidak dapat dibuka, jadi perubahan diblokir agar data lama tidak tertimpa."
        }
    }
}

nonisolated enum ScanSessionDeleteWarning: Equatable {
    case frameCleanupIncomplete
}

nonisolated struct ScanSessionDeleteOutcome: Equatable {
    var warnings: [ScanSessionDeleteWarning] = []
}

/// Batas antara state aplikasi dan penyimpanan sesi pindai.
/// Sejajar dengan `FieldRepository`, bukan menumpang padanya: tipe muatannya
/// berbeda dan kosakata berkasnya berbeda.
@MainActor
protocol ScanSessionRepository {
    func prepare() throws
    func loadSessions() throws -> [ScanSession]
    func saveSessions(_ sessions: [ScanSession]) throws
    /// Mengembalikan nama berkas saja, bukan path absolut.
    func saveFrame(_ data: Data, frameID: UUID, pathExtension: String) throws -> String
    func deleteFrame(named filename: String) -> Bool
    func frameURL(filename: String) -> URL?
}
