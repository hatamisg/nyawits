import Combine
import Foundation
import FoundationModels

/// Pemanggil model bahasa di perangkat.
///
/// Berkas ini sengaja tipis: seluruh isi prompt ada di `InsightPromptBuilder`
/// yang murni dan bisa diuji. Di sini hanya ketersediaan, pemanggilan, dan
/// pemetaan galat.
///
/// Model berjalan DI PERANGKAT. Tidak ada data kebun yang dikirim ke jaringan —
/// satu-satunya bagian app yang menyentuh jaringan tetap klien ramalan cuaca.
@MainActor
final class FieldInsightService: ObservableObject {
    /// Suhu rendah: tugasnya meringkas fakta yang diberikan, bukan mengarang.
    private let options = GenerationOptions(temperature: 0.3, maximumResponseTokens: 400)

    /// `nil` berarti model siap dipakai.
    var unavailableReason: InsightUnavailableReason? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case let .unavailable(reason):
            switch reason {
            case .deviceNotEligible: return .deviceNotEligible
            case .appleIntelligenceNotEnabled: return .appleIntelligenceNotEnabled
            case .modelNotReady: return .modelNotReady
            @unknown default: return .failed
            }
        @unknown default:
            return .failed
        }
    }

    // MARK: - Narasi hasil heatmap

    func scanInsight(
        for snapshot: ScanInsightSnapshot
    ) async -> Result<ScanInsight, InsightUnavailableReason> {
        guard !snapshot.isEmpty else { return .failure(.noRanking) }
        if let unavailableReason { return .failure(unavailableReason) }

        let session = LanguageModelSession(instructions: InsightPromptBuilder.scanInstructions)
        do {
            let response = try await session.respond(
                to: InsightPromptBuilder.prompt(for: snapshot),
                generating: ScanInsight.self,
                options: options
            )
            return .success(response.content)
        } catch {
            return .failure(Self.reason(for: error))
        }
    }

    // MARK: - Tindakan untuk kartu Aksi

    func fieldAction(
        for snapshot: ScanInsightSnapshot
    ) async -> Result<FieldActionSuggestion, InsightUnavailableReason> {
        guard !snapshot.isEmpty else { return .failure(.noRanking) }
        if let unavailableReason { return .failure(unavailableReason) }

        let session = LanguageModelSession(instructions: InsightPromptBuilder.actionInstructions)
        do {
            let response = try await session.respond(
                to: InsightPromptBuilder.prompt(for: snapshot),
                generating: FieldActionSuggestion.self,
                options: options
            )
            return .success(response.content)
        } catch {
            return .failure(Self.reason(for: error))
        }
    }

    /// Bentuk siap pakai untuk kartu Aksi: TIDAK PERNAH gagal.
    ///
    /// `focus` selalu nil: keluaran model hanya teks, tidak memuat baris,
    /// petak, atau sebaran tanaman, jadi ia tidak berhak mengisi bagian
    /// kartu yang menyatakan posisi di kebun.
    ///
    /// Kalau model tidak tersedia atau menolak, isinya jatuh ke teks berbasis
    /// aturan yang tetap tunduk pada batas klaim yang sama.
    func actionContent(for snapshot: ScanInsightSnapshot?) async -> FieldActionContent {
        guard let snapshot, !snapshot.isEmpty else {
            return FieldActionContent(
                isSimulation: false,
                message: InsightFallback.noSession.message,
                note: InsightFallback.noSession.note,
                focus: nil
            )
        }
        switch await fieldAction(for: snapshot) {
        case let .success(suggestion):
            return FieldActionContent(
                isSimulation: false,
                message: suggestion.message,
                note: suggestion.note,
                focus: nil
            )
        case .failure:
            let fallback = InsightFallback.action(for: snapshot)
            return FieldActionContent(
                isSimulation: false,
                message: fallback.message,
                note: fallback.note,
                focus: nil
            )
        }
    }

    private static func reason(for error: Error) -> InsightUnavailableReason {
        guard let generation = error as? LanguageModelSession.GenerationError else {
            return .failed
        }
        switch generation {
        case .unsupportedLanguageOrLocale: return .unsupportedLanguage
        case .guardrailViolation: return .guardrail
        case .exceededContextWindowSize: return .contextTooLong
        default: return .failed
        }
    }
}
