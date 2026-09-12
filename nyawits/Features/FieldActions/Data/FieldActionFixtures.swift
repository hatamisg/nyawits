import Foundation

enum FieldActionFixtures {
    static let demo = FieldActionContent(
        isSimulation: true,
        message: "Periksa saluran drainase pada mulsa ke-3, baris ke-15.",
        note: "Contoh rekomendasi, bukan hasil analisis kebun.",
        focus: FieldActionFocus(
            headline: "5 tanaman perlu diperiksa",
            rowNumber: 3,
            areaLabel: "Area kiri",
            plants: [0.72, 0.68, 0.64, 0.34, 0.28, 0.24, 0.30, 0.37, 0.61, 0.66].enumerated().map { index, ndre in
                let sequence = index + 1
                return FieldActionPlant(sequence: sequence, ndre: ndre, needsAttention: (4...8).contains(sequence))
            },
            actionTitle: "Periksa drainase",
            actionSystemImage: "drop.fill"
        )
    )
    static let unavailable = FieldActionContent(
        isSimulation: false,
        message: "Belum ada rekomendasi tindakan",
        note: "Rekomendasi untuk kebun ini belum tersedia.",
        focus: nil
    )
}
