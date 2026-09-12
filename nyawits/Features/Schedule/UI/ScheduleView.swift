import SwiftUI

/// Penjadwalan pemupukan: fase pertumbuhan (KAPAN dan APA) dan gerbang cuaca
/// (hari mana pupuk tidak terbuang).
///
/// Subsistem ini TERPISAH dari pipeline kamera dan tidak berbagi data, model,
/// maupun klaim dengannya. Penggabungan akan menyembunyikan langkah penilaian
/// petani yang justru menjadi syarat kejujuran sistem.
struct ScheduleView: View {
    let fieldID: UUID?
    let fieldName: String?

    @EnvironmentObject private var settingsStore: ScheduleSettingsStore
    @StateObject private var forecast = ForecastService()

    @State private var table: StageTable?
    @State private var thresholds: FertilizerThresholds?
    @State private var loadError: String?
    @State private var isEditingDates = false

    private var settings: ScheduleSettings? {
        fieldID.map { settingsStore.settings(for: $0) }
    }

    private var assessment: GrowthAssessment? {
        guard let table, let settings, let sowing = settings.sowingDate else { return nil }
        return try? GrowthStage.assess(
            table: table,
            sowingDate: sowing,
            transplantDate: settings.transplantDate,
            firstFlowerDate: settings.firstFlowerDate
        )
    }

    private var recommendation: ScheduleRecommendation? {
        guard let thresholds, case let .loaded(series, _) = forecast.state else { return nil }
        return FertilizerWindow.evaluate(forecast: series, thresholds: thresholds)
    }

    var body: some View {
        List {
            if let loadError {
                Section {
                    Label(loadError, systemImage: "exclamationmark.octagon.fill")
                        .foregroundStyle(.red)
                }
            }
            if fieldID == nil {
                Section {
                    Text("Pilih kebun lebih dulu. Jadwal dihitung dari tanggal semai dan pindah tanam kebun itu.")
                        .foregroundStyle(.secondary)
                }
            } else {
                datesSection
                stageSection
                scanWindowSection
                weatherSection
            }
        }
        .navigationTitle("Jadwal Pemupukan")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadTables()
            await forecast.load(
                latitude: settings?.latitude ?? OpenMeteoClient.defaultLatitude,
                longitude: settings?.longitude ?? OpenMeteoClient.defaultLongitude
            )
        }
        .sheet(isPresented: $isEditingDates) {
            if let fieldID {
                ScheduleDatesEditorView(fieldID: fieldID)
                    .environmentObject(settingsStore)
            }
        }
    }

    // MARK: - Tanggal

    private var datesSection: some View {
        Section {
            Button {
                isEditingDates = true
            } label: {
                HStack {
                    Label("Tanggal semai dan pindah tanam", systemImage: "calendar")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
            }
            if let assessment {
                LabeledContent("Umur", value: SchedulePresentation.ageText(assessment))
                    .font(.callout)
            }
        } header: {
            Text(fieldName ?? "Kebun")
        } footer: {
            if settings?.sowingDate == nil {
                Text("Isi tanggal semai dan pindah tanam. Keduanya dibutuhkan: umur dihitung dari semai, tapi seluruh rekomendasi memakai HST — dan lama persemaian bervariasi 25–30 hari, persis lebar kesalahan yang bisa membuat pupuk N tinggi diberikan saat bunga mulai keluar.")
            }
        }
    }

    // MARK: - Fase

    @ViewBuilder
    private var stageSection: some View {
        if let assessment {
            Section {
                LabeledContent("Fase", value: assessment.stageName)
                LabeledContent("Pupuk", value: assessment.fertilizer)
                LabeledContent("Dosis", value: assessment.dose)
                if let interval = assessment.intervalDays {
                    LabeledContent("Interval", value: "tiap \(interval) hari")
                }
                if assessment.shiftDays != 0 {
                    Label(
                        "Batas fase digeser \(assessment.shiftDays) hari mengikuti tanggal bunga pertama. Pengamatan mengalahkan kalender.",
                        systemImage: "eye"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                ForEach(assessment.messages, id: \.self) { message in
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Fase sekarang")
            } footer: {
                Text(SchedulePresentation.stageSourceCaveat)
            }
        }
    }

    @ViewBuilder
    private var scanWindowSection: some View {
        if let assessment, !assessment.scanWindows.isEmpty {
            Section {
                ForEach(assessment.scanWindows) { window in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(window.name).font(.callout.weight(.medium))
                            Spacer()
                            Text(window.status.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(window.status == .open ? .green : .secondary)
                        }
                        Text(SchedulePresentation.rangeLabel(window.startDate, window.endDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(window.reason)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Jendela sesi pindai")
            } footer: {
                Text("Dua scan, bukan lima sampai tujuh: potensi hasil terkunci di sekitar pembungaan, dan keduanya jatuh pada hari Anda sudah keluar untuk memupuk. Kalau hanya sanggup satu, ambil Scan 1.")
            }
        }
    }

    // MARK: - Cuaca

    @ViewBuilder
    private var weatherSection: some View {
        switch forecast.state {
        case .idle, .loading:
            Section("Gerbang cuaca") {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Mengambil ramalan…").foregroundStyle(.secondary)
                }
            }
        case let .failed(message):
            Section("Gerbang cuaca") {
                Label(message, systemImage: "wifi.slash")
                    .font(.footnote)
                    .foregroundStyle(.red)
                Button("Coba lagi") { Task { await reloadForecast() } }
            }
        case let .loaded(_, origin):
            if let recommendation {
                originSection(origin)
                recommendationSection(recommendation)
                daysSection(recommendation)
            }
        }
    }

    private func originSection(_ origin: ForecastOrigin) -> some View {
        Section {
            Label(
                SchedulePresentation.originText(origin),
                systemImage: origin.isStale ? "clock.badge.exclamationmark" : "checkmark.circle"
            )
            .font(.footnote)
            .foregroundStyle(origin.isStale ? .orange : .secondary)
            Button("Perbarui ramalan") { Task { await reloadForecast() } }
                .font(.footnote)
        } header: {
            Text("Sumber ramalan")
        }
    }

    @ViewBuilder
    private func recommendationSection(_ recommendation: ScheduleRecommendation) -> some View {
        Section {
            if recommendation.allRed {
                Label(FertilizerWindow.allRedMessage, systemImage: "xmark.octagon.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
            } else if let day = recommendation.recommended {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(SchedulePresentation.dayLabel(day.date))
                            .font(.headline)
                        if let caveat = recommendation.recommendationCaveat {
                            Text(caveat)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.2), in: Capsule())
                        }
                    }
                    Text(day.action).font(.callout)
                    Text(day.reason).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Hari yang disarankan")
        } footer: {
            Text(SchedulePresentation.thresholdCaveat)
        }
    }

    private func daysSection(_ recommendation: ScheduleRecommendation) -> some View {
        Section("Jendela ramalan") {
            ForEach(recommendation.days) { day in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(color(for: day.status))
                            .frame(width: 10, height: 10)
                        Text(SchedulePresentation.dayLabel(day.date))
                            .font(.callout.weight(.medium))
                        Spacer()
                        Text(day.status.title)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(color(for: day.status))
                    }
                    Text(day.reason).font(.caption).foregroundStyle(.secondary)
                    Text(day.action).font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func color(for status: FertilizerStatus) -> Color {
        switch status {
        case .green: .green
        case .yellow: .orange
        case .red: .red
        }
    }

    // MARK: - Pemuatan

    private func loadTables() {
        do {
            table = try StageTable.loadFromBundle()
            thresholds = try FertilizerThresholds.loadFromBundle()
            loadError = nil
        } catch let error as StageTable.LoadError {
            loadError = error.message
        } catch let error as FertilizerThresholds.LoadError {
            loadError = error.message
        } catch let error as BundleJSONResource.LoadError {
            loadError = error.message
        } catch {
            loadError = "Tabel jadwal tidak dapat dibaca."
        }
    }

    private func reloadForecast() async {
        await forecast.load(
            latitude: settings?.latitude ?? OpenMeteoClient.defaultLatitude,
            longitude: settings?.longitude ?? OpenMeteoClient.defaultLongitude
        )
    }
}
