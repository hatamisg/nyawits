import Foundation

struct FertilizationDate: Identifiable {
    let id: String
    let day: Int
    let month: String
    let isHighlighted: Bool
}

/// Presentation-ready content; no weather decisions are inferred by the UI.
///
/// Ketersediaan jadwal ditentukan oleh `dates`, BUKAN oleh `isSimulation`:
/// `isSimulation` hanyalah label asal data, bukan pengganti status boleh/tunda.
struct FertilizationContent {
    let isSimulation: Bool
    let dates: [FertilizationDate]
    /// Baris footnote pada keadaan kosong.
    let detail: String
    /// Baris utama pada keadaan kosong.
    var headline: String = "Belum ada jadwal pemupukan"
    /// Baris di bawah deretan tanggal, saat tanggalnya ada.
    var caption: String = ""

    var hasSchedule: Bool { !dates.isEmpty }
}
