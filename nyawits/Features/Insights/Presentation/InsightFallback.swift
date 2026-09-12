import Foundation

/// Teks pengganti saat model tidak tersedia atau gagal.
///
/// Ada supaya kartu tidak pernah kosong dan tidak pernah menampilkan bahasa
/// Inggris ke petani. Isinya berbasis aturan dan tetap tunduk pada batas klaim
/// yang sama: ia menunjuk ke mana harus pergi, tidak pernah menyebut penyebab.
nonisolated enum InsightFallback {
    static func summary(for snapshot: ScanInsightSnapshot) -> String {
        guard let first = snapshot.plots.first else {
            return "Belum ada petak yang bisa diperingkat di sesi ini."
        }
        let others = snapshot.plots.dropFirst().prefix(2).map(\.title)
        if others.isEmpty {
            return "Kunjungi \(first.title) lebih dulu."
        }
        return "Kunjungi \(first.title) lebih dulu, lalu \(others.joined(separator: " dan "))."
    }

    static let checks: [String] = [
        "Apakah tanah di polibagnya lebih kering daripada petak lain?",
        "Apakah petak itu kena bayangan sebagian hari?",
        "Apakah tanamannya baru dipindah belakangan?",
        "Apakah ada yang aneh pada daunnya, seperti bercak atau menguning?"
    ]

    static let recordReminder =
        "Catat apa yang Anda lihat di catatan sesi ini. Alat ini tidak bisa menebak sebabnya."

    /// Tindakan untuk kartu Aksi.
    static func action(for snapshot: ScanInsightSnapshot) -> (message: String, note: String) {
        guard let first = snapshot.plots.first else {
            return (
                message: "Belum ada rekomendasi tindakan",
                note: "Tutup satu sesi pindai dulu, supaya petaknya bisa diurutkan."
            )
        }
        return (
            message: "Periksa \(first.title) lebih dulu saat berkeliling.",
            note: "Petak itu paling tertinggal di sesi ini. Sebabnya belum tentu pupuk, jadi lihat sendiri dulu lalu catat."
        )
    }

    static let noSession = (
        message: "Belum ada rekomendasi tindakan",
        note: "Rekomendasi muncul setelah satu sesi pindai ditutup."
    )
}
