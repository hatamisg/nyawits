import Foundation

/// Tabel fase pertumbuhan, dibaca dari `Resources/Schedule/stages.json`.
///
/// Hubungan umur -> fase -> penekanan hara sudah DITETAPKAN rekomendasi
/// agronomi; ia tidak ditemukan dari data. Melatih model untuk mereproduksi
/// tabel adalah cara termahal mendapat tabel yang kurang akurat.
nonisolated struct StageTable: Equatable {
    nonisolated struct Stage: Equatable {
        let name: String
        var startHST: Int
        var endHST: Int
        let fertilizer: String
        let dose: String
        let intervalDays: Int?
    }

    nonisolated struct ScanWindow: Equatable {
        let name: String
        let startHST: Int
        let endHST: Int
        let reason: String
        let priority: String
    }

    let stages: [Stage]
    let scanWindows: [ScanWindow]
    /// `_sumber`: dinas pertanian kabupaten, BUKAN publikasi penelitian.
    /// Wajib bisa ditampilkan, jangan disembunyikan.
    let sourceNotes: [String]
    let scanNotes: [String]

    static let resourceName = "stages"
    static let resourceSubdirectory = "Schedule"

    /// Nama fase yang batasnya ikut bergeser saat tanggal bunga diketahui.
    /// `persemaian` tidak ikut: ia berakhir di HST 0 menurut definisi.
    static let shiftableStages: Set<String> = ["vegetatif", "pembungaan", "pembuahan"]
    static let floweringStageName = "pembungaan"

    private struct Payload: Decodable {
        struct Fase: Decodable {
            let nama: String
            let hstMulai: Int
            let hstSelesai: Int
            let pupuk: String
            let dosis: String
            let intervalHari: Int?

            enum CodingKeys: String, CodingKey {
                case nama
                case hstMulai = "hst_mulai"
                case hstSelesai = "hst_selesai"
                case pupuk
                case dosis
                case intervalHari = "interval_hari"
            }
        }

        struct Scan: Decodable {
            let nama: String
            let hstMulai: Int
            let hstSelesai: Int
            let kenapa: String
            let prioritas: String

            enum CodingKeys: String, CodingKey {
                case nama
                case hstMulai = "hst_mulai"
                case hstSelesai = "hst_selesai"
                case kenapa
                case prioritas
            }
        }

        let fase: [Fase]
        let scan: [Scan]
        let sumber: [String]?
        let catatanScan: [String]?

        enum CodingKeys: String, CodingKey {
            case fase
            case scan
            case sumber = "_sumber"
            case catatanScan = "_catatan_scan"
        }
    }

    enum LoadError: Error, Equatable {
        case malformedJSON
        case emptyTable

        var message: String {
            switch self {
            case .malformedJSON: "Tabel fase pertumbuhan tidak dapat dibaca."
            case .emptyTable: "Tabel fase pertumbuhan kosong."
            }
        }
    }

    static func load(data: Data) throws -> StageTable {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            throw LoadError.malformedJSON
        }
        guard !payload.fase.isEmpty else { throw LoadError.emptyTable }
        return StageTable(
            stages: payload.fase.map {
                Stage(name: $0.nama, startHST: $0.hstMulai, endHST: $0.hstSelesai,
                      fertilizer: $0.pupuk, dose: $0.dosis, intervalDays: $0.intervalHari)
            },
            scanWindows: payload.scan.map {
                ScanWindow(name: $0.nama, startHST: $0.hstMulai, endHST: $0.hstSelesai,
                           reason: $0.kenapa, priority: $0.prioritas)
            },
            sourceNotes: payload.sumber ?? [],
            scanNotes: payload.catatanScan ?? []
        )
    }

    static func loadFromBundle(_ bundle: Bundle = .main) throws -> StageTable {
        try load(data: BundleJSONResource.data(
            named: resourceName,
            subdirectory: resourceSubdirectory,
            bundle: bundle
        ))
    }
}

nonisolated enum ScanWindowStatus: Equatable {
    case upcoming(daysAway: Int)
    case open
    case passed

    var label: String {
        switch self {
        case let .upcoming(days): "\(days) hari lagi"
        case .open: "SEKARANG — jendelanya terbuka"
        case .passed: "sudah lewat"
        }
    }
}

nonisolated struct ScanWindowAssessment: Equatable, Identifiable {
    let name: String
    let reason: String
    let priority: String
    let startDate: Date
    let endDate: Date
    let status: ScanWindowStatus

    var id: String { name }
}

nonisolated struct GrowthAssessment: Equatable {
    /// Hari setelah semai.
    let hss: Int
    /// Hari setelah pindah tanam. Nil kalau belum dipindah.
    let hst: Int?
    let stageName: String
    let fertilizer: String
    let dose: String
    let intervalDays: Int?
    /// Batas fase setelah pergeseran, untuk ditampilkan apa adanya.
    let stageStartHST: Int
    let stageEndHST: Int
    /// Pergeseran yang diterapkan karena tanggal bunga diketahui. 0 = kalender murni.
    let shiftDays: Int
    let messages: [String]
    let scanWindows: [ScanWindowAssessment]
}

nonisolated enum GrowthStageError: Error, Equatable {
    case transplantBeforeSowing

    var message: String {
        "Tanggal pindah tanam mendahului tanggal semai. Periksa kembali kedua tanggalnya."
    }
}

/// Penentu fase pertumbuhan.
///
/// TITIK NOLNYA DUA TANGGAL, dan itu penting. Umur dihitung dari semai, tapi
/// seluruh rekomendasi memakai HST (hari setelah pindah tanam). Konversinya
/// bergantung lama persemaian yang bervariasi 25–30 hari — dan 5 hari itu
/// persis lebar kesalahan yang berbahaya, karena bisa membuat pupuk N tinggi
/// diberikan saat bunga mulai keluar. Karena itu modul ini MENUNTUT dua tanggal
/// dan menghitung sendiri, alih-alih menebak lama persemaian.
nonisolated enum GrowthStage {
    static let seedlingMessage =
        "Bibit umumnya siap pindah setelah 4 daun sejati (~25–30 hari). Isi tanggal pindah tanam supaya jadwal pemupukan bisa dihitung."
    static let floweringWarning =
        "N tinggi di fase ini merontokkan bunga."
    static let flowerCheckPrompt =
        "Sudah muncul bunga pertama? Kalau ya, masukkan tanggalnya — pengamatan lebih tepat daripada kalender."

    static func assess(
        table: StageTable,
        sowingDate: Date,
        transplantDate: Date?,
        firstFlowerDate: Date? = nil,
        today: Date = Date(),
        calendar: Calendar = .current
    ) throws -> GrowthAssessment {
        if let transplantDate, calendar.startOfDay(for: transplantDate) < calendar.startOfDay(for: sowingDate) {
            throw GrowthStageError.transplantBeforeSowing
        }

        let hss = days(from: sowingDate, to: today, calendar: calendar)

        guard let transplantDate else {
            // Belum dipindah: fase persemaian, tanpa pemupukan susulan.
            let seedling = table.stages.first
            return GrowthAssessment(
                hss: hss,
                hst: nil,
                stageName: seedling?.name ?? "persemaian",
                fertilizer: seedling?.fertilizer ?? "belum ada pemupukan susulan",
                dose: seedling?.dose ?? "-",
                intervalDays: seedling?.intervalDays,
                stageStartHST: seedling?.startHST ?? -999,
                stageEndHST: seedling?.endHST ?? 0,
                shiftDays: 0,
                messages: [seedlingMessage],
                scanWindows: []
            )
        }

        let hst = days(from: transplantDate, to: today, calendar: calendar)

        // PENGAMATAN MENGALAHKAN KALENDER. Kalender hanya perkiraan; kalau bunga
        // pertama sudah terlihat, tanggalnya yang menentukan peralihan.
        var shift = 0
        var stages = table.stages
        if let firstFlowerDate,
           let floweringStart = table.stages.first(where: { $0.name == StageTable.floweringStageName })?.startHST {
            let floweringHST = days(from: transplantDate, to: firstFlowerDate, calendar: calendar)
            shift = floweringHST - floweringStart
            stages = stages.map { stage in
                guard StageTable.shiftableStages.contains(stage.name) else { return stage }
                var shifted = stage
                // Pengawalan menjaga sentinel (999, -999) dan batas nol tidak
                // ikut bergeser, sehingga LEBAR tiap fase tetap.
                if shifted.endHST < 900 { shifted.endHST += shift }
                if shifted.startHST > 0 { shifted.startHST += shift }
                return shifted
            }
        }

        let stage = stages.first(where: { hst >= $0.startHST && hst < $0.endHST }) ?? stages[stages.count - 1]

        var messages: [String] = []
        if stage.name == StageTable.floweringStageName {
            messages.append(floweringWarning)
        }
        if stage.name == "vegetatif", firstFlowerDate == nil {
            let untilTransition = stage.endHST - hst
            if (1...10).contains(untilTransition) {
                messages.append(flowerCheckPrompt)
            }
        }

        return GrowthAssessment(
            hss: hss,
            hst: hst,
            stageName: stage.name,
            fertilizer: stage.fertilizer,
            dose: stage.dose,
            intervalDays: stage.intervalDays,
            stageStartHST: stage.startHST,
            stageEndHST: stage.endHST,
            shiftDays: shift,
            messages: messages,
            scanWindows: scanWindows(
                table: table,
                transplantDate: transplantDate,
                hst: hst,
                calendar: calendar
            )
        )
    }

    /// Jendela scan dihitung dari `tanggal_pindah_tanam + hst_mulai/hst_selesai`,
    /// tanpa pergeseran bunga — itulah yang didefinisikan tabelnya.
    static func scanWindows(
        table: StageTable,
        transplantDate: Date,
        hst: Int,
        calendar: Calendar = .current
    ) -> [ScanWindowAssessment] {
        table.scanWindows.map { window in
            let start = calendar.date(byAdding: .day, value: window.startHST,
                                      to: calendar.startOfDay(for: transplantDate)) ?? transplantDate
            let end = calendar.date(byAdding: .day, value: window.endHST,
                                    to: calendar.startOfDay(for: transplantDate)) ?? transplantDate
            let status: ScanWindowStatus
            if hst < window.startHST {
                status = .upcoming(daysAway: window.startHST - hst)
            } else if hst <= window.endHST {
                status = .open
            } else {
                status = .passed
            }
            return ScanWindowAssessment(
                name: window.name,
                reason: window.reason,
                priority: window.priority,
                startDate: start,
                endDate: end,
                status: status
            )
        }
    }

    static func days(from start: Date, to end: Date, calendar: Calendar) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: end)
        ).day ?? 0
    }
}
