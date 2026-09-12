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

    Pekerjaan utamamu MENERJEMAHKAN: mengubah angka dan istilah yang sulit menjadi \
    kalimat yang langsung dimengerti orang yang sehari-hari bekerja di kebun.
    """

    private static let dataMeaning = """
    DATA YANG KAMU TERIMA
    Urutan petak di dalam SATU sesi pindai pada SATU kebun. Nomor 1 berarti paling \
    tertinggal dibandingkan petak lain di sesi yang sama. Itu peringkat relatif, \
    bukan nilai mutlak, dan bukan berarti tanamannya sakit.
    """

    /// Istilah sulit yang sering muncul di dunia pertanian atau di data ini,
    /// beserta padanan sehari-harinya.
    ///
    /// Tugas utama model di sini memang MENERJEMAHKAN: petani tidak perlu belajar
    /// kosakata baru untuk memakai alatnya. Daftar ini dikirim apa adanya supaya
    /// penggantiannya tidak diserahkan pada tebakan model.
    static let jargonReplacements: [(avoid: String, use: String)] = [
        ("vigor", "pertumbuhan"),
        ("skor, indeks, persentil, normalisasi", "urutan, atau nomor berapa"),
        ("relatif", "dibanding petak lain"),
        ("defisiensi", "kekurangan"),
        ("kanopi", "daun yang rimbun"),
        ("media tanam", "tanah di polibag"),
        ("aplikasi pupuk", "memupuk"),
        ("irigasi", "menyiram"),
        ("monitoring, observasi", "mengecek, melihat"),
        ("gejala", "tanda yang kelihatan"),
        ("optimal", "paling baik"),
        ("signifikan", "kelihatan jelas"),
        ("faktor", "hal"),
        ("mengindikasikan", "menandakan")
    ]

    /// Aturan gaya bahasa. Dipisah dari `prohibitions` supaya bisa diuji sendiri.
    static let plainLanguageRules: [String] = [
        "Jawab SELALU dalam Bahasa Indonesia, apa pun bahasa yang kamu kira diminta.",
        "Pakai bahasa sehari-hari, seperti sedang mengobrol dengan tetangga di kebun. Bukan bahasa laporan dan bukan bahasa penyuluhan resmi.",
        "Satu kalimat berisi satu maksud saja. Usahakan tidak lebih dari lima belas kata.",
        "Kalau sebuah istilah sulit tidak bisa dihindari, tulis maksudnya dengan kata biasa, jangan istilahnya.",
        "Jangan memakai singkatan, kata asing, atau kata serapan yang jarang dipakai di kebun.",
        "Sebut petak memakai namanya seperti tertulis di data, bukan nomor ID atau kode.",
        "Tulis seperti berbicara langsung kepada pemilik kebun."
    ]

    private static var style: String {
        let glossary = jargonReplacements
            .map { "- jangan tulis \"\($0.avoid)\" — tulis \"\($0.use)\"" }
            .joined(separator: "\n")
        let rules = plainLanguageRules
            .map { "- \($0)" }
            .joined(separator: "\n")
        return """
        GAYA BAHASA
        Orang yang membaca ini petani cabai, bukan penyuluh dan bukan peneliti. \
        Sebagian besar tidak terbiasa dengan istilah teknis. Tugasmu membuat isinya \
        mudah dimengerti, bukan terdengar pintar.

        \(rules)

        GANTI ISTILAH SULIT
        \(glossary)
        """
    }

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
        petani PERIKSA sendiri di petak itu, masing-masing sebagai pertanyaan pendek yang \
        bisa langsung dijawab dengan melihat atau meraba. Tutup dengan ajakan singkat \
        mencatat temuannya di catatan lapangan.
        """)
    }

    /// Instruksi untuk satu tindakan di kartu Aksi.
    static var actionInstructions: String {
        instructions(task: """
        Tulis SATU tindakan paling berguna yang bisa petani lakukan hari ini, dalam satu \
        kalimat perintah yang pendek dan langsung bisa dikerjakan. Tambahkan satu kalimat \
        alasan yang menegaskan bahwa ini masih perlu diperiksa, bukan sesuatu yang sudah \
        dipastikan.
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
