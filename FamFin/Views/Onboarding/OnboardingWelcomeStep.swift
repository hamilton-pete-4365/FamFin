import SwiftUI

/// First onboarding step: welcomes the user and explains envelope budgeting.
struct OnboardingWelcomeStep: View {
    var onContinue: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            OnboardingWelcomeIllustration()

            VStack(spacing: 12) {
                Text("Welcome to FamFin")
                    .font(.largeTitle.bold())

                Text("Give every pound a job")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal)

            Spacer()

            OnboardingWelcomeExplanation()

            Spacer()

            OnboardingWelcomeButtons(
                onContinue: onContinue,
                onSkip: onSkip
            )
        }
        .padding()
    }
}

// MARK: - Illustration

struct OnboardingWelcomeIllustration: View {
    var body: some View {
        HStack(spacing: 24) {
            OnboardingEnvelopeIcon(
                systemImage: "house.fill",
                color: .blue,
                label: "Bills"
            )
            OnboardingEnvelopeIcon(
                systemImage: "cart.fill",
                color: .green,
                label: "Groceries"
            )
            OnboardingEnvelopeIcon(
                systemImage: "airplane",
                color: .orange,
                label: "Holiday"
            )
        }
        .padding(.bottom, 24)
        .accessibilityHidden(true)
    }
}

/// A single "envelope" icon for the welcome illustration.
struct OnboardingEnvelopeIcon: View {
    let systemImage: String
    let color: Color
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(color.gradient)
                .clipShape(.rect(cornerRadius: 12))

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Explanation

struct OnboardingWelcomeExplanation: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingBulletPoint(
                systemImage: "envelope.fill",
                text: "Allocate your income into budget categories — like putting cash into envelopes"
            )
            OnboardingBulletPoint(
                systemImage: "chart.pie.fill",
                text: "Track spending against each category to stay on target"
            )
            OnboardingBulletPoint(
                systemImage: "target",
                text: "Set savings goals and watch your progress grow"
            )
        }
        .padding(.horizontal)
    }
}

/// A single bullet point with an icon and description.
struct OnboardingBulletPoint: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Buttons

struct OnboardingWelcomeButtons: View {
    var onContinue: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button {
                onContinue()
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Skip Setup") {
                onSkip()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.bottom)
    }
}

#Preview {
    OnboardingWelcomeStep(onContinue: {}, onSkip: {})
}
