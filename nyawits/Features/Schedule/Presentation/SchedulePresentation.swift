import Foundation

nonisolated enum SchedulePresentation {
    static func dayLabel(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "EEEE, d MMM"
        return formatter.string(from: date)
    }

    static func rangeLabel(_ start: Date, _ end: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    static func originText(_ origin: ForecastOrigin, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMM HH:mm"
        switch origin {
        case let .live(fetchedAt):
            return "Ramalan terbaru, diambil \(formatter.string(from: fetchedAt))."
        case let .cachedCopy(fetchedAt, reason):
            return "SALINAN LAMA dari \(formatter.string(from: fetchedAt)) — bukan ramalan terbaru. \(reason)"
        }
    }

    static func ageText(_ assessment: GrowthAssessment) -> String {
        guard let hst = assessment.hst else {
            return "\(assessment.hss) HSS · belum dipindah tanam"
        }
        return "\(hst) HST · \(assessment.hss) HSS"
    }

    /// Catatan yang wajib ikut kalau tabel fase ditampilkan.
    static let stageSourceCaveat =
        "Tabel fase berasal dari dinas pertanian kabupaten, BUKAN publikasi penelitian. Kalau penyuluh setempat punya anjuran untuk Batam, anjuran itu lebih diutamakan karena menyesuaikan tanah dan iklimnya."

    /// Catatan yang wajib ikut kalau gerbang cuaca ditampilkan.
    static let thresholdCaveat =
        "Ambang cuaca di bawah adalah NILAI AWAL dan belum dikalibrasi untuk polybag di Batam. Ia berasal dari pedoman agronomi umum untuk pupuk N."
}
