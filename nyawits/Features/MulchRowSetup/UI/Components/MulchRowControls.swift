import SwiftUI

struct MulchRowControls: View {
    @FocusState private var isRowCountFocused: Bool

    let rowCount: Int
    let rotationDegrees: Double
    let onRowCountChanged: (Int) -> Void
    let onRotationChanged: (Double) -> Void
    let onRotationEditingChanged: (Bool) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "line.3.horizontal")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.cyan)
                    .frame(width: 48, height: 48)
                    .background(Color(uiColor: .secondarySystemBackground), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Mulch rows")
                        .font(.headline.weight(.bold))
                    Text("Enter the number found in this field")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                rowCountInput
            }

            HStack(spacing: 10) {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(.secondary)

                Slider(
                    value: Binding(
                        get: { rotationDegrees },
                        set: onRotationChanged
                    ),
                    in: 0...179,
                    step: 1,
                    onEditingChanged: onRotationEditingChanged
                )
                .tint(.cyan)
                .disabled(rowCount == 0)

                Text("\(Int(rotationDegrees.rounded()))°")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .frame(width: 42, alignment: .trailing)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Row rotation")
            .accessibilityValue("\(Int(rotationDegrees.rounded())) degrees")
        }
    }

    private var rowCountInput: some View {
        HStack(spacing: 0) {
            Button {
                onRowCountChanged(rowCount - 1)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 40, height: 44)
            }
            .disabled(rowCount == 0)
            .accessibilityLabel("Remove one row")

            TextField(
                "0",
                value: Binding(
                    get: { rowCount },
                    set: onRowCountChanged
                ),
                format: .number
            )
            .keyboardType(.numberPad)
            .focused($isRowCountFocused)
            .multilineTextAlignment(.center)
            .font(.headline.monospacedDigit())
            .frame(width: 44, height: 44)
            .accessibilityLabel("Number of mulch rows")

            Button {
                onRowCountChanged(rowCount + 1)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 40, height: 44)
            }
            .disabled(rowCount >= 200)
            .accessibilityLabel("Add one row")
        }
        .foregroundStyle(.primary)
        .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isRowCountFocused = false
                }
            }
        }
    }
}
