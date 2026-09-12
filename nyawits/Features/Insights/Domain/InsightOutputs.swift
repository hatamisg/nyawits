import FoundationModels

/// Narasi hasil satu sesi pindai.
///
/// `checks` sengaja berupa PERTANYAAN yang perlu diperiksa petani, bukan
/// kesimpulan. Alat ini tidak bisa menyebut penyebab ketertinggalan, dan
/// skema ini memaksa bentuk keluarannya mengikuti batas itu.
@Generable(description: "Ringkasan hasil pemindaian kebun untuk petani cabai")
struct ScanInsight {
    @Guide(description: "Satu sampai dua kalimat. Sebut petak mana yang paling perlu dikunjungi lebih dulu. Tanpa menyebut penyebab.")
    var summary: String

    @Guide(
        description: "Hal yang perlu DIPERIKSA petani di lapangan, ditulis sebagai pertanyaan singkat. Bukan kesimpulan, bukan dosis pupuk.",
        .maximumCount(4)
    )
    var checks: [String]

    @Guide(description: "Satu kalimat ajakan mencatat temuan di catatan lapangan.")
    var recordReminder: String
}

/// Satu tindakan untuk kartu Aksi di layar Home.
///
/// Bentuknya sengaja sebangun dengan `FieldActionContent` (`message` + `note`)
/// supaya penyambungan ke kartu tinggal memetakan dua field.
@Generable(description: "Satu tindakan konkret yang bisa dilakukan petani hari ini")
struct FieldActionSuggestion {
    @Guide(description: "Satu kalimat perintah pendek, langsung, maksimal sekitar 90 karakter.")
    var message: String

    @Guide(description: "Satu kalimat alasan yang menegaskan hal ini masih perlu diperiksa, bukan sudah dipastikan.")
    var note: String
}
