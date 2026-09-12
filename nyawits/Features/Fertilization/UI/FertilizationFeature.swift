import SwiftUI

/// Home passes field context here; service integration belongs inside this feature.
struct FertilizationFeature: View {
    let fieldID: UUID?
    let isDemo: Bool

    @EnvironmentObject private var settingsStore: ScheduleSettingsStore
    @StateObject private var viewModel = FertilizationViewModel()

    var body: some View {
        NavigationLink {
            ScheduleView(fieldID: fieldID, fieldName: nil)
        } label: {
            FertilizationCard(content: viewModel.content)
        }
        .buttonStyle(.plain)
        // id: memuat ulang saat kebun aktif berganti; SwiftUI membatalkan
        // permintaan yang sudah basi.
        .task(id: TaskKey(fieldID: fieldID, isDemo: isDemo)) {
            await viewModel.reload(isDemo: isDemo, settings: fieldID.map { settingsStore.settings(for: $0) })
        }
    }

    private struct TaskKey: Equatable {
        let fieldID: UUID?
        let isDemo: Bool
    }
}

#if DEBUG
#Preview { FertilizationFeature(fieldID: nil, isDemo: true).padding() }
#endif
