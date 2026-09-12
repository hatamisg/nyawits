import Foundation

/// Label kualitatif posisi satu petak DI DALAM sesinya.
///
/// Sengaja tidak ada angka mutlak dan tidak ada persentase kesehatan: tanpa
/// kartu terkalibrasi, skala simulasi dan lapangan tidak sama. Yang sah adalah
/// URUTAN, dan label yang jelas-jelas relatif.
nonisolated enum VigorStanding: String, Equatable, Sendable, CaseIterable {
    case mostLagging = "Paling tertinggal"
    case middle = "Menengah"
    case leading = "Terdepan"

    var title: String { rawValue }
}

nonisolated struct MeasurementRow: Equatable, Identifiable {
    let measurementID: UUID
    let title: String
    let subtitle: String
    /// Nil selama sesi belum ditutup: petak memang BELUM punya skor.
    let visitPriority: Int?
    let standing: VigorStanding?
    /// Posisi 0…1 untuk tangga warna, dihitung dari PERINGKAT, bukan dari nilai
    /// skor mentah — supaya warnanya tidak pernah terbaca sebagai nilai mutlak.
    let palettePosition: Double?
    let hasFieldNote: Bool

    var id: UUID { measurementID }
}

nonisolated enum ScanSessionPresentation {

    // MARK: - Sesi

    static func sortSessions(_ sessions: [ScanSession]) -> [ScanSession] {
        sessions.sorted { a, b in
            if a.openedAt != b.openedAt { return a.openedAt > b.openedAt }
            return a.id.uuidString < b.id.uuidString
        }
    }

    static func sessionTitle(_ session: ScanSession, calendar: Calendar = .current) -> String {
        if let label = session.label { return label }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMM yyyy"
        return "Sesi \(formatter.string(from: session.openedAt))"
    }

    static func sessionStatusText(_ session: ScanSession) -> String {
        let count = session.measurementCount
        let plots = count == 1 ? "1 petak" : "\(count) petak"
        return session.isClosed ? "Ditutup · \(plots)" : "Terbuka · \(plots)"
    }

    /// Pesan yang muncul selama sesi masih terbuka. UI harus MENGATAKAN bahwa
    /// skornya belum ada, bukan menampilkan nol atau tanda hubung tanpa penjelasan.
    static func openSessionExplanation(_ session: ScanSession) -> String {
        let remaining = ScanSession.suggestedMinimumMeasurements - session.measurementCount
        let base = "Petak belum punya skor. Skor dibandingkan terhadap petak terbaik di kebun ini, jadi pembandingnya baru ada setelah sesi ditutup."
        guard remaining > 0 else { return base }
        return base + " Tambahkan sekitar \(remaining) petak lagi supaya pembandingnya bermakna."
    }

    // MARK: - Petak

    static func measurementTitle(_ measurement: PlantMeasurement) -> String {
        if let label = measurement.label,
           !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return label
        }
        if let rowNumber = measurement.rowNumber,
           let side = measurement.side,
           let sequence = measurement.plantSequence {
            return "Baris \(rowNumber) · \(side.title) · tanaman \(sequence)"
        }
        return "Petak tanpa nama"
    }

    static func measurementSubtitle(_ measurement: PlantMeasurement) -> String {
        let bandCount = measurement.bands.count
        let expected = BandLabel.allCases.count
        if bandCount < expected {
            return "\(bandCount) dari \(expected) band terukur — belum lengkap"
        }
        if let note = measurement.fieldNote,
           !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return note
        }
        return "\(expected) band terukur"
    }

    /// Baris daftar petak. `ranking` nil berarti sesi belum ditutup.
    static func rows(
        for session: ScanSession,
        ranking: SessionRanking?
    ) -> [MeasurementRow] {
        let ordered: [PlantMeasurement]
        if let ranking {
            let position = Dictionary(
                uniqueKeysWithValues: ranking.scored.enumerated().map { ($1.measurementID, $0) }
            )
            ordered = session.measurements.sorted { lhs, rhs in
                switch (position[lhs.id], position[rhs.id]) {
                case let (l?, r?): l < r
                case (nil, _?): false
                case (_?, nil): true
                default: lhs.recordedAt < rhs.recordedAt
                }
            }
        } else {
            ordered = session.measurements.sorted { $0.recordedAt < $1.recordedAt }
        }

        let total = ranking?.scored.count ?? 0
        return ordered.map { measurement in
            let scored = ranking?.scored.first(where: { $0.measurementID == measurement.id })
            return MeasurementRow(
                measurementID: measurement.id,
                title: measurementTitle(measurement),
                subtitle: measurementSubtitle(measurement),
                visitPriority: scored?.visitPriority,
                standing: scored.map { standing(priority: $0.visitPriority, total: total) },
                palettePosition: scored.map { palettePosition(priority: $0.visitPriority, total: total) },
                hasFieldNote: !(measurement.fieldNote ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
    }

    /// Sepertiga terbawah paling tertinggal, sepertiga teratas terdepan.
    static func standing(priority: Int, total: Int) -> VigorStanding {
        guard total > 2 else { return priority == 1 ? .mostLagging : .leading }
        let third = Double(total) / 3
        if Double(priority) <= third { return .mostLagging }
        if Double(priority) <= third * 2 { return .middle }
        return .leading
    }

    /// 0 = paling tertinggal (ujung kuning), 1 = terdepan (ujung hijau).
    static func palettePosition(priority: Int, total: Int) -> Double {
        guard total > 1 else { return 0.5 }
        return Double(priority - 1) / Double(total - 1)
    }

    // MARK: - Batas klaim

    /// Aturan keras 10 dan 11. Ini teks tentang APA YANG BOLEH DITULIS DI LAYAR,
    /// terpisah dari `peringatan` model yang dibaca langsung dari JSON.
    static let claimLimits: [String] = [
        "Yang ditampilkan URUTAN, bukan nilai klorofil. Satu skor yang sama bisa cocok dengan rentang klorofil selebar ~30 µg/cm² antar kebun, jadi angka mutlak tidak sah walaupun urutannya sah.",
        "Alat ini TIDAK bisa menyebut PENYEBAB. Petak yang kering, ternaungi, atau terlambat pindah tanam ikut terbaca tertinggal persis seperti petak yang kurang pupuk. Isi catatan lapangan — di situlah penyebabnya terekam.",
        "Ini penunjuk prioritas kunjungan, BUKAN penentu dosis pupuk.",
        "Peringkat hanya berlaku DI DALAM satu sesi dan satu kebun. Membandingkan skor antar sesi atau antar kebun tidak sah karena pembandingnya berbeda."
    ]

    /// Angka ketepatan boleh ditampilkan hanya kalau kedua catatan ini ikut.
    static let accuracyClaim = "Petak terlemah tertebak benar 95,0–95,8 % pada simulasi (menebak asal 16,7 %)."
    static let accuracyCaveats: [String] = [
        "Angka itu dari SIMULASI, bukan hasil lapangan.",
        "Ia mengandaikan frame RGB mentah dengan white balance terkunci — rantai pemrosesan kamera tidak dimodelkan sama sekali, dan itu asumsi terbesar yang menyangganya."
    ]

    static func warningText(_ warning: RankingWarning) -> String { warning.message }
}
