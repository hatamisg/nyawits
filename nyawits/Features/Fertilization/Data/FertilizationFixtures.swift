import Foundation

enum FertilizationFixtures {
    static let demo = FertilizationContent(
        isSimulation: true,
        dates: [17, 18, 23, 25].map {
            FertilizationDate(id: "demo-aug-\($0)", day: $0, month: "AGU", isHighlighted: $0 == 17)
        },
        detail: "Tanggal 17, 18, 23, dan 25 Agustus adalah contoh tampilan. Jadwal ini bukan rekomendasi pemupukan untuk kebun Anda.",
        caption: "Contoh jadwal · Simulasi"
    )
    static let unavailable = FertilizationContent(
        isSimulation: false, dates: [],
        detail: "Belum ada jadwal pemupukan yang tersimpan untuk kebun ini."
    )
}
