import SwiftUI

/// Dua kotak ROI yang digeser tangan di atas satu frame.
///
/// ROI ditentukan MANUSIA. Segmentasi otomatis sengaja tidak dibangun:
/// masking belum diputuskan, dan menambahnya sekarang berarti mengukur sesuatu
/// yang belum pernah disimulasikan.
struct ROIBoxLayer: View {
    enum Box: String, CaseIterable, Identifiable {
        case canopy
        case card

        var id: Self { self }

        var title: String {
            switch self {
            case .canopy: "Kanopi"
            case .card: "Kartu abu-abu"
            }
        }

        var tint: Color {
            switch self {
            case .canopy: Color(red: 0.35, green: 0.85, blue: 0.4)
            case .card: Color(red: 0.95, green: 0.95, blue: 0.98)
            }
        }
    }

    @Binding var canopy: ROIRect
    @Binding var card: ROIRect
    @Binding var selected: Box

    /// Ukuran gambar terpasang di layar; ROI disimpan sebagai fraksi terhadapnya.
    let imageSize: CGSize

    private let minimumSide: Double = 0.03

    /// Kotak saat gestur dimulai. `DragGesture.translation` bersifat kumulatif
    /// sejak awal gestur, jadi menambahkannya tiap `onChanged` akan berlipat.
    @State private var dragOrigin: (box: Box, rect: ROIRect)?

    var body: some View {
        ZStack(alignment: .topLeading) {
            box(for: .canopy, rect: canopy)
            box(for: .card, rect: card)
        }
        .frame(width: imageSize.width, height: imageSize.height, alignment: .topLeading)
    }

    private func box(for kind: Box, rect: ROIRect) -> some View {
        let frame = CGRect(
            x: rect.x * imageSize.width,
            y: rect.y * imageSize.height,
            width: rect.width * imageSize.width,
            height: rect.height * imageSize.height
        )
        let isSelected = selected == kind

        return ZStack(alignment: .bottomTrailing) {
            Rectangle()
                .strokeBorder(kind.tint, lineWidth: isSelected ? 3 : 1.5)
                .background(Rectangle().fill(kind.tint.opacity(isSelected ? 0.16 : 0.07)))
                .overlay(alignment: .topLeading) {
                    Text(kind.title)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(kind.tint.opacity(0.85), in: Capsule())
                        .foregroundStyle(.black)
                        .padding(4)
                }
                .contentShape(Rectangle())
                .gesture(moveGesture(for: kind))

            // Pegangan ubah ukuran di sudut kanan-bawah.
            Circle()
                .fill(kind.tint)
                .frame(width: 26, height: 26)
                .overlay {
                    Image(systemName: "arrow.down.right")
                        .font(.caption2.bold())
                        .foregroundStyle(.black)
                }
                .offset(x: 13, y: 13)
                .gesture(resizeGesture(for: kind))
                .opacity(isSelected ? 1 : 0.45)
        }
        .frame(width: frame.width, height: frame.height)
        .offset(x: frame.minX, y: frame.minY)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kotak \(kind.title)")
        .accessibilityHint("Geser untuk memindahkan. Ketuk untuk memilih.")
    }

    private func binding(for kind: Box) -> Binding<ROIRect> {
        switch kind {
        case .canopy: $canopy
        case .card: $card
        }
    }

    /// Kotak awal gestur ini, disimpan sekali di `onChanged` pertama.
    private func startRect(for kind: Box) -> ROIRect {
        if let dragOrigin, dragOrigin.box == kind { return dragOrigin.rect }
        let rect = binding(for: kind).wrappedValue
        dragOrigin = (kind, rect)
        return rect
    }

    private func moveGesture(for kind: Box) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                selected = kind
                let start = startRect(for: kind)
                var rect = start
                let dx = Double(value.translation.width) / Double(imageSize.width)
                let dy = Double(value.translation.height) / Double(imageSize.height)
                rect.x = clamp(start.x + dx, upper: 1 - start.width)
                rect.y = clamp(start.y + dy, upper: 1 - start.height)
                binding(for: kind).wrappedValue = rect
            }
            .onEnded { _ in dragOrigin = nil }
    }

    private func resizeGesture(for kind: Box) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                selected = kind
                let start = startRect(for: kind)
                var rect = start
                let dx = Double(value.translation.width) / Double(imageSize.width)
                let dy = Double(value.translation.height) / Double(imageSize.height)
                rect.width = clamp(start.width + dx, lower: minimumSide, upper: 1 - start.x)
                rect.height = clamp(start.height + dy, lower: minimumSide, upper: 1 - start.y)
                binding(for: kind).wrappedValue = rect
            }
            .onEnded { _ in dragOrigin = nil }
    }

    private func clamp(_ value: Double, lower: Double = 0, upper: Double) -> Double {
        min(max(value, lower), max(lower, upper))
    }
}
