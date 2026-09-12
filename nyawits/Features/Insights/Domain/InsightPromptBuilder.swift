import Foundation

/// Penyusun instruksi dan prompt untuk model di perangkat.
///
/// Sengaja MURNI `Foundation` dan terpisah dari pemanggil model: isi prompt
/// adalah bagian yang paling mudah salah dan paling penting dijaga, jadi ia
/// harus bisa diuji dengan asersi tanpa menjalankan model apa pun.
///
/// Seluruh batas klaim dokumen konteks §7 diterjemahkan menjadi larangan
/// eksplisit di sini. Model tidak diberi kesempatan menyimpulkan sendiri bahwa
/// ia boleh menyebut penyebab.
nonisolated enum InsightPromptBuilder {

    /// Apa yang boleh dan tidak boleh dikatakan. Diuji satu per satu.
    static let prohibitions: [String] = [
        "JANGAN menyatakan penyebab sebagai fakta. Alat ini tidak bisa membedakan petak yang kurang pupuk dari petak yang kering, ternaungi, atau terlambat pindah tanam. Sebut kemungkinan HANYA sebagai hal yang perlu DIPERIKSA petani.",
        "JANGAN menyebut nilai klorofil, satuan ug/cm2, atau persentase kesehatan. Yang ada hanyalah urutan.",
        "JANGAN menyebut takaran, dosis, atau jenis pupuk apa pun.",
        "JANGAN membandingkan dengan sesi lain atau kebun lain. Pembandingnya berbeda, jadi perbandingan itu tidak sah.",
        "JANGAN menyebut angka atau fakta yang tidak ada di data di bawah. Kalau tidak tahu, katakan perlu diperiksa."
    ]

    private static let role = """
    Kamu membantu petani cabai swadaya di Batam membaca hasil pemindaian kebunnya. \
    Kamu bukan ahli yang memvonis, melainkan pembantu yang menunjukkan ke mana \
    petani sebaiknya berjalan lebih dulu.
    """

    private static let dataMeaning = """
    DATA YANG KAMU TERIMA
    Urutan petak di dalam SATU sesi pindai pada SATU kebun. Nomor 1 berarti paling \
    tertinggal dibandingkan petak lain di sesi yang sama. Itu peringkat relatif, \
    bukan nilai mutlak, dan bukan berarti tanamannya sakit.
    """

    private static let style = """
    GAYA
    Bahasa Indonesia sederhana untuk petani. Kalimat pendek. Tanpa istilah teknis \
    dan tanpa angka yang tidak ada di data. Sebut petak memakai namanya, bukan nomor ID.
    """

    private static func instructions(task: String) -> String {
        let rules = prohibitions.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        return """
        \(role)

        \(dataMeaning)

        LARANGAN KERAS
        \(rules)

        \(style)

        TUGAS
        \(task)
        """
    }

    /// Instruksi untuk narasi hasil heatmap.
    static var scanInstructions: String {
        instructions(task: """
        Ringkas hasil sesi ini dalam satu sampai dua kalimat, sebutkan petak mana yang \
        paling perlu dikunjungi lebih dulu. Lalu susun paling banyak empat hal yang perlu \
        petani PERIKSA sendiri di petak itu. Tutup dengan ajakan singkat mencatat temuannya \
        di catatan lapangan.
        """)
    }

    /// Instruksi untuk satu tindakan di kartu Aksi.
    static var actionInstructions: String {
        instructions(task: """
        Tulis SATU tindakan paling berguna yang bisa petani lakukan hari ini, dalam satu \
        kalimat perintah yang pendek. Tambahkan satu kalimat alasan yang menegaskan bahwa \
        ini masih perlu diperiksa, bukan sesuatu yang sudah dipastikan.
        """)
    }

    /// Badan prompt: hanya fakta dari sesi, tanpa tafsir.
    static func prompt(for snapshot: ScanInsightSnapshot) -> String {
        var lines: [String] = [
            "Kebun: \(snapshot.fieldName)",
            "Sesi: \(snapshot.sessionTitle)",
            "Jumlah petak yang diperingkat: \(snapshot.plots.count)"
        ]
        if snapshot.excludedCount > 0 {
            lines.append("Petak yang tidak bisa dihitung: \(snapshot.excludedCount)")
        }

        lines.append("")
        lines.append("Urutan kunjungan, nomor 1 paling tertinggal:")
        for plot in snapshot.plots {
            var line = "\(plot.visitPriority). \(plot.title) — \(plot.standing)"
            if let note = plot.fieldNote {
                line += " — catatan petani: \(note)"
            }
            lines.append(line)
        }

        if !snapshot.warnings.isEmpty {
            lines.append("")
            lines.append("Catatan sesi:")
            lines.append(contentsOf: snapshot.warnings.map { "- \($0)" })
        }

        return lines.joined(separator: "\n")
    }
}
