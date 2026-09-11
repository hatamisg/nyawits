import SwiftUI

struct FieldActionCard: View {
    let content: FieldActionContent
    private var isDemo: Bool { content.isSimulation }
    var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Aksi", systemImage: "rectangle.pattern.checkered")
                        .font(.headline)
                        .foregroundStyle(.blue)
                    Spacer()
                    if isDemo {
                        Text("SIMULASI")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(content.message)
                    .font(.body)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(content.note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
