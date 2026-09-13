import SwiftUI

/// Gaya label untuk judul kartu di layar Home.
///
/// Pada ukuran teks aksesibilitas, ikon hiasan disembunyikan supaya judulnya
/// mendapat seluruh lebar kartu. Tanpa ini, ikon memakan sepertiga lebar dan
/// judul sependek "Pemupukan" pun terpenggal di tengah kata.
///
/// Ikonnya memang hiasan: maknanya sepenuhnya dibawa teksnya, jadi tidak ada
/// informasi yang hilang saat ia disembunyikan.
struct CardTitleLabelStyle: LabelStyle {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeBody(configuration: Configuration) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            configuration.title
        } else {
            Label(configuration)
        }
    }
}

extension LabelStyle where Self == CardTitleLabelStyle {
    static var cardTitle: CardTitleLabelStyle { CardTitleLabelStyle() }
}
