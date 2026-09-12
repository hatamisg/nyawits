import SwiftUI
import UIKit

struct HomeEmptyState: View {
    @ObservedObject var store: FieldMappingStore
    let prepareNewField: () -> Void
    let handleSelectDemo: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 92, height: 92)
                Image(systemName: "map.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 7) {
                Text("Belum ada kebun")
                    .font(.title3.weight(.bold))
                Text("Buat batas kebun dan baris mulsa, lalu foto tanaman satu per satu.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: prepareNewField) {
                Label("Petakan Kebun", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.green, in: Capsule())
            }

            if !store.isDemoSelected {
                Button("Lihat demo") {
                    handleSelectDemo()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(24)
        .background(.background, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.top, 28)
    
    }

}

#if DEBUG
#Preview {
    HomeEmptyState(store: PreviewFixtures.store(empty: true), prepareNewField: {}, handleSelectDemo: {}).padding()
}
#endif
