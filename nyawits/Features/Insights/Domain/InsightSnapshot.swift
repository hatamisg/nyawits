import Foundation

/// Satu petak sebagaimana ia akan diceritakan ke model.
///
/// Sengaja memakai istilah yang SAMA dengan yang dilihat pengguna di layar
/// (lewat `ScanSessionPresentation`), supaya model tidak memperkenalkan kosakata
/// baru yang tidak ada di UI.
nonisolated struct PlotSummary: Equatable, Identifiable {
    let measurementID: UUID
    /// 1 = kunjungan pertama = paling tertinggal.
    let visitPriority: Int
    let title: String
    /// "Paling tertinggal" / "Menengah" / "Terdepan".
    let standing: String
    /// Catatan petani. Ini satu-satunya tempat penyebab ketertinggalan terekam,
    /// jadi ia ikut ke prompt apa adanya.
    let fieldNote: String?

    var id: UUID { measurementID }
}

/// Seluruh konteks yang boleh dilihat model untuk satu sesi pindai.
///
/// TIDAK memuat data penjadwalan pemupukan: §9 memisahkan kedua subsistem, dan
/// penggabungan akan menyembunyikan langkah penilaian petani.
nonisolated struct ScanInsightSnapshot: Equatable {
    let fieldName: String
    let sessionTitle: String
    /// Petak yang berhasil dihitung dan masuk peringkat.
    let plots: [PlotSummary]
    /// Petak yang dikeluarkan karena pengukurannya belum lengkap.
    let excludedCount: Int
    /// Peringatan tingkat sesi, apa adanya dari `RankingWarning`.
    let warnings: [String]

    var isEmpty: Bool { plots.isEmpty }

    /// Susun dari sesi yang SUDAH ditutup. Sesi terbuka tidak punya peringkat,
    /// jadi tidak ada yang bisa dinarasikan.
    static func make(
        fieldName: String,
        session: ScanSession,
        ranking: SessionRanking
    ) -> ScanInsightSnapshot {
        var notes: [UUID: String] = [:]
        for measurement in session.measurements {
            let trimmed = (measurement.fieldNote ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { notes[measurement.id] = trimmed }
        }

        let plots = ScanSessionPresentation.rows(for: session, ranking: ranking)
            .compactMap { row -> PlotSummary? in
                guard let priority = row.visitPriority, let standing = row.standing else {
                    return nil
                }
                return PlotSummary(
                    measurementID: row.measurementID,
                    visitPriority: priority,
                    title: row.title,
                    standing: standing.title,
                    fieldNote: notes[row.measurementID]
                )
            }

        return ScanInsightSnapshot(
            fieldName: fieldName,
            sessionTitle: ScanSessionPresentation.sessionTitle(session),
            plots: plots,
            excludedCount: ranking.excluded.count,
            warnings: ranking.warnings.map(ScanSessionPresentation.warningText)
        )
    }
}

/// Kenapa saran dari model tidak tersedia. Dipakai untuk memilih teks pengganti
/// dan, kalau perlu, menjelaskan ke pengguna.
nonisolated enum InsightUnavailableReason: Error, Equatable {
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unsupportedLanguage
    case guardrail
    case contextTooLong
    case noRanking
    case failed

    /// Pesan berbahasa Indonesia. Seluruhnya berakhir sama: saran otomatis
    /// tidak muncul, tapi peringkatnya sendiri tetap sah dan tetap ditampilkan.
    var message: String {
        switch self {
        case .deviceNotEligible:
            "Perangkat ini belum mendukung saran otomatis."
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence belum diaktifkan di perangkat ini."
        case .modelNotReady:
            "Model di perangkat belum siap. Coba lagi nanti."
        case .unsupportedLanguage:
            "Model di perangkat belum mendukung bahasa Indonesia."
        case .guardrail:
            "Saran otomatis tidak dapat ditampilkan untuk data ini."
        case .contextTooLong:
            "Sesi ini terlalu panjang untuk diringkas otomatis."
        case .noRanking:
            "Peringkat belum ada. Tutup sesi lebih dulu."
        case .failed:
            "Saran otomatis gagal dibuat."
        }
    }
}
