import Combine
import Foundation

/// Mengisi kartu Pemupukan dengan jadwal sungguhan.
///
/// Menggabungkan tiga sumber yang sudah ada — tanggal tanam (`ScheduleSettingsStore`),
/// tabel fase dan ambang cuaca dari bundle, dan ramalan Open-Meteo — lalu
/// memetakannya ke `FertilizationContent` tanpa mengubah tata letak kartu.
///
/// Yang TIDAK boleh terjadi di sini: menampilkan hari aman ketika ramalan gagal
/// dan tidak ada salinan tersimpan. Kartu harus kosong dan mengatakan kenapa.
@MainActor
final class FertilizationViewModel: ObservableObject {
    @Published private(set) var content = FertilizationFixtures.unavailable

    private let forecastService: ForecastService
    private var table: StageTable?
    private var thresholds: FertilizerThresholds?
    private var tableError: String?

    init(forecastService: ForecastService? = nil) {
        self.forecastService = forecastService ?? ForecastService()
    }

    /// Dipanggil dari `.task(id:)`, jadi permintaan yang basi dibatalkan SwiftUI.
    func reload(isDemo: Bool, settings: ScheduleSettings?) async {
        if isDemo {
            content = FertilizationFixtures.demo
            return
        }
        guard let settings, let sowingDate = settings.sowingDate else {
            content = Self.empty(
                headline: "Belum ada jadwal pemupukan",
                detail: "Isi tanggal semai dan pindah tanam kebun ini supaya fase dan jadwalnya bisa dihitung."
            )
            return
        }

        loadTablesIfNeeded()
        guard let table, let thresholds else {
            content = Self.empty(
                headline: "Jadwal tidak dapat dihitung",
                detail: tableError ?? "Tabel fase pertumbuhan tidak dapat dibaca."
            )
            return
        }

        let assessment = try? GrowthStage.assess(
            table: table,
            sowingDate: sowingDate,
            transplantDate: settings.transplantDate,
            firstFlowerDate: settings.firstFlowerDate
        )
        guard let assessment else {
            content = Self.empty(
                headline: "Tanggal tanam belum masuk akal",
                detail: GrowthStageError.transplantBeforeSowing.message
            )
            return
        }

        await forecastService.load(
            latitude: settings.latitude ?? OpenMeteoClient.defaultLatitude,
            longitude: settings.longitude ?? OpenMeteoClient.defaultLongitude
        )
        if Task.isCancelled { return }

        switch forecastService.state {
        case let .loaded(forecast, origin):
            let plan = FertilizerWindow.evaluate(forecast: forecast, thresholds: thresholds)
            content = Self.content(assessment: assessment, plan: plan, origin: origin)
        case let .failed(message):
            // Gagal TANPA salinan: kosongkan. Jangan pernah menandai hari aman.
            content = Self.empty(headline: "Ramalan cuaca belum tersedia", detail: message)
        case .idle, .loading:
            content = Self.empty(
                headline: "Menyiapkan jadwal…",
                detail: "Sedang mengambil ramalan cuaca untuk kebun ini."
            )
        }
    }

    private func loadTablesIfNeeded() {
        guard table == nil || thresholds == nil else { return }
        do {
            table = try StageTable.loadFromBundle()
            thresholds = try FertilizerThresholds.loadFromBundle()
            tableError = nil
        } catch let error as StageTable.LoadError {
            tableError = error.message
        } catch let error as FertilizerThresholds.LoadError {
            tableError = error.message
        } catch let error as BundleJSONResource.LoadError {
            tableError = error.message
        } catch {
            tableError = "Tabel jadwal tidak dapat dibaca."
        }
    }

    // MARK: - Pemetaan ke bentuk kartu yang sudah ada

    private static func empty(headline: String, detail: String) -> FertilizationContent {
        FertilizationContent(isSimulation: false, dates: [], detail: detail, headline: headline)
    }

    private static func content(
        assessment: GrowthAssessment,
        plan: ScheduleRecommendation,
        origin: ForecastOrigin
    ) -> FertilizationContent {
        let safeDays = plan.days.filter { $0.status == .green }
        guard !safeDays.isEmpty else {
            return empty(
                headline: plan.allRed ? "Tunda dulu pemupukan" : "Belum ada hari yang ideal",
                detail: plan.allRed
                    ? FertilizerWindow.allRedMessage
                    : "Tidak ada hari HIJAU dalam jendela ramalan. Ketuk untuk melihat hari terbaik yang ada beserta alasannya."
            )
        }

        let recommended = plan.recommended?.date
        let dates = safeDays.prefix(4).map { day in
            FertilizationDate(
                id: ISO8601DateFormatter().string(from: day.date),
                day: Calendar.current.component(.day, from: day.date),
                month: monthLabel(day.date),
                isHighlighted: day.date == recommended
            )
        }

        var caption = "Fase \(assessment.stageName) · \(assessment.fertilizer)"
        if origin.isStale {
            caption = "Salinan lama · " + caption
        }

        return FertilizationContent(
            isSimulation: false,
            dates: Array(dates),
            detail: plan.recommended?.action ?? "",
            caption: caption
        )
    }

    private static func monthLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }
}
