import SwiftUI

struct FertilizationCard: View {
    let content: FertilizationContent
    private var isDemo: Bool { content.isSimulation }
    @State private var showsSchedule = false
    @ScaledMetric(relativeTo: .title2) private var dateDiameter: CGFloat = 60

    var body: some View {
        VStack(spacing: 12) {
            Button { showsSchedule = true } label: {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Label("Pemupukan", systemImage: "calendar.badge.clock")
                            .foregroundStyle(.orange)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .font(.headline)

                    if isDemo {
                        ViewThatFits(in: .horizontal) {
                            scheduleDates
                            ScrollView(.horizontal) {
                                scheduleDates
                            }
                            .scrollIndicators(.hidden)
                        }
                        Text("Contoh jadwal · Simulasi")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Belum ada jadwal pemupukan")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("Jadwal untuk kebun ini belum tersedia.")
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
            .buttonStyle(.plain)
            .accessibilityHint("Lihat keterangan jadwal pemupukan")
        }
        .alert("Jadwal pemupukan", isPresented: $showsSchedule) {
            Button("Tutup", role: .cancel) {}
        } message: {
            Text(content.detail)
        }
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
                                .accessibilityLabel("\(day) \(date.month), contoh jadwal")
                            }
                        }
    }

}
