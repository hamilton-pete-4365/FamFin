import SwiftUI

/// Final onboarding step: celebration with tips and a start button.
struct OnboardingCompletionStep: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            OnboardingCompletionCelebration(showCheckmark: showCheckmark)

            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.largeTitle.bold())

                Text("Your budget is ready to go. Here are a few tips to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)

            OnboardingCompletionTips()

            Spacer()

            Button {
                onFinish()
            } label: {
                Text("Start Budgeting")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom)
        }
        .padding()
        .onAppear {
            withAnimation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.6).delay(0.3)) {
                showCheckmark = true
            }
        }
    }
}

// MARK: - Celebration

struct OnboardingCompletionCelebration: View {
    let showCheckmark: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 120, height: 120)

            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.green)
                .scaleEffect(showCheckmark ? 1.0 : 0.3)
                .opacity(showCheckmark ? 1.0 : 0.0)
        }
        .padding(.bottom, 24)
        .accessibilityLabel("Setup complete")
    }
}

// MARK: - Tips

struct OnboardingCompletionTips: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingTipRow(
                systemImage: "hand.tap.fill",
                title: "Tap to budget",
                description: "Tap any budget cell to allocate money to a category"
            )
            OnboardingTipRow(
                systemImage: "arrow.left.arrow.right",
                title: "Swipe for actions",
                description: "Swipe transactions to edit or delete them"
            )
            OnboardingTipRow(
                systemImage: "banknote.fill",
                title: "Track accounts",
                description: "Add your accounts to keep balances in sync with your budget"
            )
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }
}

/// A single tip row with icon, title, and description.
struct OnboardingTipRow: View {
    let systemImage: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingCompletionStep(onFinish: {})
}
