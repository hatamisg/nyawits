import SwiftUI

/// Baris rapat pemilih konteks (PLAN §5): satu simbol peta, nama headline,
/// metadata dan satu baris status/progres. Konten hanya informasi — aksi
/// (select/ellipsis) dimiliki parent row sebagai sibling.
struct FieldListCard: View {
    let field: MappedField
    var isActive: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var mapIconSize: CGFloat = 38
    @ScaledMetric(relativeTo: .body) private var rowSpacing: CGFloat = 10

    init(field: MappedField, isActive: Bool = false) {
        self.field = field
        self.isActive = isActive
    }

    private var summary: FieldProgressSummary {
        FieldListPresentation.progressSummary(for: field)
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Ukuran aksesibilitas: satu kolom penuh tanpa ikon agar nama utuh.
                VStack(alignment: .leading, spacing: 5) {
                    Text(field.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if isActive { activeBadge }
                    Text(FieldListPresentation.metadataText(for: field))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(FieldListPresentation.compactStatusText(for: field))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                horizontalContent
            }
        }
        .padding(.vertical, rowSpacing)
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    private var horizontalContent: some View {
        HStack(alignment: .center, spacing: 12) {
            mapThumbnail

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(field.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if isActive { activeBadge }
                }

                Text(FieldListPresentation.metadataText(for: field))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(FieldListPresentation.compactStatusText(for: field))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Separator baris mulai sejajar kolom teks, bukan di bawah ikon peta.
            .alignmentGuide(.listRowSeparatorLeading) { dimensions in
                dimensions[.leading]
            }
        }
    }

    private var activeBadge: some View {
        // Checkmark + teks: indikator aktif tidak bergantung warna saja.
        HStack(spacing: 3) {
            Image(systemName: "checkmark")
                .font(.caption2.weight(.bold))
                .accessibilityHidden(true)
            Text("Aktif")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.green)
    }

    private var mapThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.green.opacity(0.12))
            Image(systemName: "map.fill")
                .font(.system(size: mapIconSize * 0.55, weight: .medium))
                .foregroundStyle(.green)
        }
        .frame(width: mapIconSize + 14, height: mapIconSize + 14)
        .accessibilityHidden(true)
    }

    private var accessibilityText: String {
        var label = "\(field.name). "
        if isActive { label += "Aktif. " }
        label += "\(FieldListPresentation.metadataText(for: field)). "
        label += FieldListPresentation.compactStatusText(for: field)
        return label
    }
}

// MARK: - Isolated Preview Fixtures

struct FieldListCard_Previews: PreviewProvider {
    static var inProgressField: MappedField {
        var field = NDREDemoFactory.makeField()
        field.name = "Kebun Cabai Utara"
        field.isDemo = false
        // 8 dari 20 sisi selesai
        let rows = field.rows
        var sides: [String] = []
        for i in 0..<4 {
            sides.append(MappedField.completionKey(rowID: rows[i].id, side: .left))
            sides.append(MappedField.completionKey(rowID: rows[i].id, side: .right))
        }
        field.completedRowSides = sides
        return field
    }

    static var completedField: MappedField {
        var field = NDREDemoFactory.makeField()
        field.name = "Kebun Blok Barat"
        field.isDemo = false
        field.completedRowSides = field.rows.flatMap { row in
            PlantCaptureSide.allCases.map { MappedField.completionKey(rowID: row.id, side: $0) }
        }
        return field
    }

    static var notMappedField: MappedField {
        let base = NDREDemoFactory.makeField()
        var field = MappedField(name: "Kebun Baru Buka", plan: base.plan, observations: [])
        field.isDemo = false
        field.completedRowSides = []
        return field
    }

    static var zeroRowsField: MappedField {
        let boundary = FieldBoundary(
            id: UUID(),
            points: [
                BoundaryPoint(coordinate: CLLocationCoordinate2D(latitude: -6.9, longitude: 107.6)),
                BoundaryPoint(coordinate: CLLocationCoordinate2D(latitude: -6.901, longitude: 107.6)),
                BoundaryPoint(coordinate: CLLocationCoordinate2D(latitude: -6.901, longitude: 107.601)),
                BoundaryPoint(coordinate: CLLocationCoordinate2D(latitude: -6.9, longitude: 107.601))
            ],
            areaSquareMeters: 520,
            perimeterMeters: 100
        )
        let plan = MulchRowPlan(boundary: boundary, rows: [], rotationDegrees: 0)
        return MappedField(name: "Kebun Tanpa Baris", plan: plan, observations: [])
    }

    static var longNameField: MappedField {
        var field = inProgressField
        field.name = "Kebun Percobaan Varietas Cabai Rawit Merah Unggul Dataran Tinggi Lembang Blok 3A"
        return field
    }

    static var previews: some View {
        Group {
            VStack(spacing: 12) {
                FieldListCard(field: inProgressField, isActive: true)
                FieldListCard(field: completedField)
                FieldListCard(field: notMappedField)
                FieldListCard(field: zeroRowsField)
            }
            .padding()
            .background(Color(uiColor: .systemGroupedBackground))
            .previewDisplayName("Standar (Light)")

            VStack(spacing: 12) {
                FieldListCard(field: inProgressField, isActive: true)
                FieldListCard(field: completedField)
            }
            .padding()
            .background(Color(uiColor: .systemGroupedBackground))
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")

            VStack(spacing: 12) {
                FieldListCard(field: longNameField, isActive: true)
                FieldListCard(field: notMappedField)
            }
            .padding()
            .background(Color(uiColor: .systemGroupedBackground))
            .environment(\.dynamicTypeSize, .accessibility3)
            .previewDisplayName("Accessibility Dynamic Type")
        }
    }
}
