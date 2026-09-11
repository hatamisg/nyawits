import Foundation

enum FieldActionFixtures {
    static let demo = FieldActionContent(
        isSimulation: true,
        message: "Periksa saluran drainase pada mulsa ke-3, baris ke-15.",
        note: "Contoh rekomendasi, bukan hasil analisis kebun."
    )
    static let unavailable = FieldActionContent(
        isSimulation: false,
        message: "Belum ada rekomendasi tindakan",
        note: "Rekomendasi untuk kebun ini belum tersedia."
    )
}
