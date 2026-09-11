import SwiftUI

struct FieldBoundarySummaryBar: View {
    let boundary: FieldBoundary

    var body: some View {
        HStack(spacing: 8) {
            // 1. Points (Field boundary - logo from select field area)
            summaryItem(
                icon: {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.green)
                        .frame(width: 34, height: 34)
                        .background {
                            Circle().fill(.ultraThinMaterial)
                                .overlay(Circle().fill(Color.black.opacity(0.48)))
                        }
                        .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
                },
                value: "\(boundary.points.count) points",
                label: "Field boundary"
            )

            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 0.75, height: 28)

            // 2. Estimated area
            summaryItem(
                icon: {
                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 21, weight: .regular))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 34, height: 34)
                },
                value: FieldMeasurementFormatter.area(boundary.areaSquareMeters),
                label: "Estimated area"
            )

            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 0.75, height: 28)

            // 3. Total perimeter
            summaryItem(
                icon: {
                    Image(systemName: "ruler")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color(red: 0.5, green: 0.78, blue: 1.0))
                        .frame(width: 34, height: 34)
                },
                value: FieldMeasurementFormatter.distance(boundary.perimeterMeters),
                label: "Total perimeter"
            )
        }
        .padding(.vertical, 2)
    }

    private func summaryItem<Icon: View>(
        @ViewBuilder icon: () -> Icon,
        value: String,
        label: String
    ) -> some View {
        HStack(spacing: 6) {
            icon()

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MulchRowControls: View {
    @FocusState private var isRowCountFocused: Bool

    let boundary: FieldBoundary
    let rowCount: Int
    let rotationDegrees: Double
    let onRowCountChanged: (Int) -> Void
    let onRotationChanged: (Double) -> Void
    let onRotationEditingChanged: (Bool) -> Void

    var body: some View {
        VStack(spacing: 12) {
            FieldBoundarySummaryBar(boundary: boundary)

            Divider()
                .overlay(Color.white.opacity(0.14))

            HStack(spacing: 12) {
                Image(systemName: "line.3.horizontal")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.cyan)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle().fill(.ultraThinMaterial)
                            .overlay(Circle().fill(Color.black.opacity(0.48)))
                    }
                    .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Mulch rows")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Enter the number found in this field")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer(minLength: 4)

                rowCountInput
            }

            HStack(spacing: 10) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.65))

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
                    .foregroundStyle(.white)
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 40)
            }
            .disabled(rowCount == 0)
            .opacity(rowCount == 0 ? 0.35 : 1.0)
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
            .font(.headline.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .accessibilityLabel("Number of mulch rows")

            Button {
                onRowCountChanged(rowCount + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 40)
            }
            .disabled(rowCount >= 200)
            .opacity(rowCount >= 200 ? 0.35 : 1.0)
            .accessibilityLabel("Add one row")
        }
        .background {
            Capsule().fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Color.black.opacity(0.48)))
        }
        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
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
