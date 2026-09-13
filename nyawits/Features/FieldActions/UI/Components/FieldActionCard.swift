import SwiftUI

struct FieldActionCard: View {
    let content: FieldActionContent
    var onAction: () -> Void = {}
    @ScaledMetric(relativeTo: .headline) private var actionGlyph: CGFloat = 50
    @ScaledMetric(relativeTo: .headline) private var actionRowHeight: CGFloat = 78

    var body: some View {
        Group {
            if let focus = content.focus {
                focusedCard(focus)
            } else {
                unavailableCard
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.primary.opacity(0.045), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.055), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
    }

    private func focusedCard(_ focus: FieldActionFocus) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            FieldActionCardHeader(isSimulation: content.isSimulation)

            VStack(alignment: .leading, spacing: 3) {
                Text(focus.headline)
                    .font(.cardMessage)
                    .foregroundStyle(.primary)
                Text("Baris \(focus.rowNumber)  ·  \(focus.areaLabel)")
                    .font(.cardSecondary)
                    .foregroundStyle(.secondary)
            }

            FieldActionPlantStrip(plants: focus.plants)

            Button(action: onAction) {
                HStack(spacing: 14) {
                    Image(systemName: focus.actionSystemImage)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.blue)
                        .frame(width: actionGlyph, height: actionGlyph)
                        .background(.blue.opacity(0.12), in: Circle())
                    Text(focus.actionTitle)
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: actionGlyph, height: actionGlyph)
                        .background(.primary.opacity(0.045), in: Circle())
                }
                .padding(.horizontal, 8)
                .frame(minHeight: actionRowHeight)
                .background(.blue.opacity(0.085), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Membuka panduan tindakan")
        }
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldActionCardHeader(isSimulation: false)
            Text(content.message)
                .font(.cardMessage)
            Text(content.note)
                .font(.cardCaption)
                .foregroundStyle(.secondary)
        }
    }
}

struct FieldActionPlantStrip: View {
    let plants: [FieldActionPlant]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(plants) { plant in
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(.secondary.opacity(0.14))
                        .frame(width: 1, height: 10)
                    Circle()
                        .fill(VigorPalette.color(plant.ndre))
                        .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 0.8))
                        .frame(width: 22, height: 22)
                    Rectangle()
                        .fill(.secondary.opacity(0.14))
                        .frame(width: 1, height: 10)
                }
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 84)
        
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sebaran tanaman")
        .accessibilityValue("\(plants.filter(\.needsAttention).count) dari \(plants.count) tanaman perlu diperiksa")
    }
}

private struct FieldActionCardHeader: View {
    let isSimulation: Bool
    @ScaledMetric(relativeTo: .caption) private var badgeHeight: CGFloat = 42

    private var title: some View {
        Label("Aksi", systemImage: "rectangle.pattern.checkered")
            .foregroundStyle(.blue)
            .labelStyle(.cardTitle)
            .font(.cardLabel)
    }

    @ViewBuilder
    private var badge: some View {
        if isSimulation {
            Text("SIMULASI")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .frame(height: badgeHeight)
                .background(.primary.opacity(0.045), in: Capsule())
        }
    }

    var body: some View {
        // Sama seperti kartu Pemupukan: mendatar selama muat, menurun saat
        // ukuran teks aksesibilitas membuat judul dan lencana berebut lebar.
        ViewThatFits(in: .horizontal) {
            HStack {
                title
                Spacer()
                badge
            }
            VStack(alignment: .leading, spacing: 8) {
                title
                badge
            }
        }
    }
}

#if DEBUG
#Preview("Rekomendasi tindakan") {
    FieldActionCard(content: FieldActionFixtures.demo)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Belum ada rekomendasi") {
    FieldActionCard(content: FieldActionFixtures.unavailable)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Strip tanaman") {
    FieldActionPlantStrip(plants: FieldActionFixtures.demo.focus!.plants)
        .padding()
}
#endif
