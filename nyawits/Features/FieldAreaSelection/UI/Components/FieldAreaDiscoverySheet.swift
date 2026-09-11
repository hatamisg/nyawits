import SwiftUI

struct FieldAreaDiscoveryStep: Identifiable, Equatable {
    let id: Int
    let imageName: String
    let title: String
    let subtitle: String
}

struct FieldAreaDiscoverySheet: View {
    var onDismiss: () -> Void = {}
    @State private var currentStep: Int = 0
    @State private var dragOffset: CGFloat = 0

    private let steps: [FieldAreaDiscoveryStep] = [
        FieldAreaDiscoveryStep(
            id: 0,
            imageName: "toolarea_1",
            title: "Create a field boundary",
            subtitle: "Tap once on the map to place points and outline your field as a polygon."
        ),
        FieldAreaDiscoveryStep(
            id: 1,
            imageName: "toolarea_2",
            title: "Adjust boundary points",
            subtitle: "Drag any numbered marker to adjust its position. Boundary lines cannot cross."
        )
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Drag Indicator Handle
            Capsule()
                .fill(Color.secondary.opacity(0.42))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .accessibilityHidden(true)

            TabView(selection: $currentStep) {
                ForEach(steps) { step in
                    VStack(spacing: 16) {
                        Image(step.imageName)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .padding(.horizontal, 20)
                            .accessibilityHidden(true)

                        VStack(spacing: 8) {
                            Text(step.title)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)

                            Text(step.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                        }
                    }
                    .tag(step.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom Page Indicator Dots
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(currentStep == index ? Color.blue : Color(.systemGray4))
                        .frame(width: 8, height: 8)
                        .scaleEffect(currentStep == index ? 1.0 : 0.9)
                        .animation(.easeInOut(duration: 0.25), value: currentStep)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(currentStep + 1) of \(steps.count)")

            // Bottom Primary Action Button
            Button(action: handleAction) {
                Text(currentStep < steps.count - 1 ? "Next" : "Get Started")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 520)
        .background(
            Color(uiColor: .systemBackground)
        )
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: -4)
        .offset(y: max(0, dragOffset))
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 || value.predictedEndTranslation.height > 200 {
                        closeSheet()
                    } else {
                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            currentStep = 0
            dragOffset = 0
        }
    }

    private func handleAction() {
        if currentStep < steps.count - 1 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentStep += 1
            }
        } else {
            closeSheet()
        }
    }

    private func closeSheet() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            onDismiss()
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.gray.ignoresSafeArea()
        FieldAreaDiscoverySheet()
            .ignoresSafeArea(edges: .bottom)
    }
}
