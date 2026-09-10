import Foundation

enum FieldListProgressStatus: String, Equatable, Sendable {
    case notMapped = "Belum dipetakan"
    case inProgress = "Pemetaan berlangsung"
    case completed = "Pemetaan selesai"

    var title: String {
        rawValue
    }
}

struct FieldProgressSummary: Equatable, Sendable {
    let status: FieldListProgressStatus
    let numerator: Int
    let denominator: Int
    let fraction: Double
    let progressText: String

    init(
        status: FieldListProgressStatus,
        numerator: Int,
        denominator: Int,
        fraction: Double,
        progressText: String
    ) {
        self.status = status
        self.numerator = numerator
        self.denominator = denominator
        self.fraction = fraction
        self.progressText = progressText
    }
}

enum FieldListPresentation {
    /// Koleksi nyata hanya `isDemo != true`; legacy `nil` tetap dianggap nyata.
    static func filterRealFields(_ fields: [MappedField]) -> [MappedField] {
        fields.filter { $0.isDemo != true }
    }

    /// Urutan `updatedAt` descending. Untuk tanggal sama, tie-break ID stabil agar posisi tidak berubah acak.
    static func sortFields(_ fields: [MappedField]) -> [MappedField] {
        fields.sorted { a, b in
            if a.updatedAt != b.updatedAt {
                return a.updatedAt > b.updatedAt
            }
            return a.id.uuidString < b.id.uuidString
        }
    }

    /// Query di-trim; pencarian nama memakai perbandingan lokal case dan diacritic insensitive.
    /// String kosong/whitespace mengembalikan semua kebun. Tidak mencari foto atau isi observasi.
    static func searchFields(_ fields: [MappedField], query: String) -> [MappedField] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fields }
        return fields.filter { field in
            field.name.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    /// Menghasilkan daftar kebun nyata yang tersortir dan terfilter oleh query pencarian.
    static func visibleRealFields(from fields: [MappedField], query: String) -> [MappedField] {
        let realFields = filterRealFields(fields)
        let sorted = sortFields(realFields)
        return searchFields(sorted, query: query)
    }

    /// Hitung status progres dan ringkasan penyelesaian.
    /// Numerator: Set dari `completedRowSides` intersect keys valid milik rows dan kedua sisi.
    /// Denominator: `rows.count * 2`.
    /// Zero rows: tanpa progres palsu, tampilkan "Belum ada baris".
    static func progressSummary(for field: MappedField) -> FieldProgressSummary {
        let validKeys = Set(field.rows.flatMap { row in
            PlantCaptureSide.allCases.map { MappedField.completionKey(rowID: row.id, side: $0) }
        })
        let completed = Set(field.completedRowSides ?? [])
        let validCompleted = completed.intersection(validKeys)
        let numerator = validCompleted.count
        let denominator = field.rows.count * 2

        let fraction: Double
        if denominator > 0 {
            fraction = Double(numerator) / Double(denominator)
        } else {
            fraction = 0.0
        }

        let status: FieldListProgressStatus
        if !field.rows.isEmpty && numerator == denominator {
            status = .completed
        } else if field.capturedPlantCount == 0 && numerator == 0 {
            status = .notMapped
        } else {
            status = .inProgress
        }

        let progressText: String
        if field.rows.isEmpty {
            progressText = "Belum ada baris"
        } else {
            progressText = "\(numerator) dari \(denominator) sisi selesai"
        }

        return FieldProgressSummary(
            status: status,
            numerator: numerator,
            denominator: denominator,
            fraction: fraction,
            progressText: progressText
        )
    }

    /// Satu baris status/progres ringkas untuk pemilih konteks:
    /// "Belum dipetakan" sebelum ada progres, lalu "N dari M sisi selesai".
    static func compactStatusText(for field: MappedField) -> String {
        let summary = progressSummary(for: field)
        return summary.status == .notMapped ? "Belum dipetakan" : summary.progressText
    }

    /// Format metadata ringkas: "{luas} · {jumlah baris} baris · {jumlah foto} foto"
    static func metadataText(for field: MappedField) -> String {
        let areaText = FieldMeasurementFormatter.area(field.areaSquareMeters)
        return "\(areaText) · \(field.rows.count) baris · \(field.capturedPlantCount) foto"
    }

    /// Label VoiceOver lengkap untuk kartu kebun.
    static func accessibilityLabel(for field: MappedField) -> String {
        let summary = progressSummary(for: field)
        let areaText = FieldMeasurementFormatter.area(field.areaSquareMeters)
        return "\(field.name), \(areaText), \(field.rows.count) baris, \(field.capturedPlantCount) foto, status \(summary.status.title), \(summary.progressText)"
    }
}
