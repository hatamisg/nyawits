import SwiftUI

/// Skala teks untuk kartu ringkasan di layar Home.
///
/// Kartu "Pemupukan" dan "Aksi" duduk bersebelahan dan menyampaikan hal yang
/// sejenis, jadi keduanya harus memakai ukuran yang sama untuk peran yang sama.
/// Perannya diberi nama di sini, bukan ditulis sebagai `.body` atau
/// `.title3.bold` yang tersebar di dua berkas — sudah dua kali kedua kartu
/// melenceng satu sama lain, dan dengan nama peran penyimpangan berikutnya
/// kelihatan saat menulis kode, bukan saat melihat layar.
///
/// Seluruhnya gaya semantik, jadi ikut Dynamic Type tanpa tambahan apa pun.
extension Font {
    /// Label kartu, berfungsi sebagai penanda jenis kartu. Contoh: "Pemupukan".
    static let cardLabel = Font.headline

    /// Kalimat yang dibaca sekilas — bagian paling menonjol di dalam kartu.
    static let cardMessage = Font.title3.weight(.bold)

    /// Baris pendukung di bawah pesan utama, misalnya lokasi petak.
    static let cardSecondary = Font.subheadline.weight(.medium)

    /// Penjelasan tambahan; selalu yang paling kecil di dalam kartu.
    static let cardCaption = Font.footnote
}
