import SwiftUI

struct FertilizationCard: View {
    let content: FertilizationContent
    @ScaledMetric(relativeTo: .title2) private var dateDiameter: CGFloat = 60

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 22) {
                    // Di ukuran teks aksesibilitas, ikon dan chevron merebut lebar
                    // sampai judulnya terpenggal ("Pemupu / kan"). ViewThatFits
                    // menjatuhkan chevron yang memang hanya hiasan -- seluruh kartu
                    // tetap bisa diketuk, dan petunjuknya ada di accessibilityHint.
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            cardTitle
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        cardTitle
                    }
                    .font(.headline)

                    if content.hasSchedule {
                        ViewThatFits(in: .horizontal) {
                            scheduleDates
                            ScrollView(.horizontal) {
                                scheduleDates
                            }
                            .scrollIndicators(.hidden)
                        }
                        Text(content.caption)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(content.headline)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(content.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 28))
        }
        .accessibilityHint("Buka jadwal pemupukan")
    }

    private var cardTitle: some View {
        Label("Pemupukan", systemImage: "calendar.badge.clock")
            .foregroundStyle(.orange)
            .labelStyle(.cardTitle)
    }

    private var scheduleDates: some View {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(content.dates) { date in
                                let day = date.day
                                VStack(spacing: 6) {
                                    VStack(spacing: 0) {
                                        Text("\(day)")
                                            .font(.title3.bold().monospacedDigit())
                                        Text(date.month).font(.caption.weight(.medium))
                                    }
                                    .frame(width: dateDiameter, height: dateDiameter)
                                    .foregroundStyle(date.isHighlighted ? Color.white : Color.primary)
                                    .background(date.isHighlighted ? Color.green : Color(uiColor: .systemGroupedBackground),
                                                in: Circle())
                                    Circle()
                                        .fill(date.isHighlighted ? Color.green : Color.clear)
                                        .frame(width: 5, height: 5)
                                }
                                .frame(maxWidth: .infinity)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(
                                    content.isSimulation
                                        ? "\(day) \(date.month), contoh jadwal"
                                        : "\(day) \(date.month), hari aman memupuk"
                                )
                            }
                        }
    }

}

#if DEBUG
#Preview("Simulasi") { FertilizationCard(content: FertilizationFixtures.demo).padding() }
#Preview("Belum ada data") { FertilizationCard(content: FertilizationFixtures.unavailable).padding() }
#endif
