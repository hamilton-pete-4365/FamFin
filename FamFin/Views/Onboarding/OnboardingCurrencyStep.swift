import SwiftUI

/// Second onboarding step: lets the user choose their preferred currency.
struct OnboardingCurrencyStep: View {
    @Binding var currencyCode: String
    var onContinue: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            OnboardingCurrencyHeader()

            OnboardingCurrencyPreview(currencyCode: currencyCode)

            OnboardingCurrencyPicker(currencyCode: $currencyCode)

            Spacer()

            OnboardingStepButtons(
                continueLabel: "Continue",
                onContinue: onContinue,
                onSkip: onSkip
            )
        }
        .padding()
    }
}

// MARK: - Header

struct OnboardingCurrencyHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "coloncurrencysign.circle.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("Choose Your Currency")
                .font(.title2.bold())

            Text("This affects how amounts are displayed. You can change it later in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 24)
    }
}

// MARK: - Preview

struct OnboardingCurrencyPreview: View {
    let currencyCode: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var previewAmount: String {
        let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
        return "\(currency.symbol)1,234.56"
    }

    var body: some View {
        Text(previewAmount)
            .font(.title.bold())
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(.rect(cornerRadius: 12))
            .padding(.bottom, 16)
            .contentTransition(reduceMotion ? .identity : .numericText())
            .accessibilityLabel("Preview: \(previewAmount)")
    }
}

// MARK: - Picker

struct OnboardingCurrencyPicker: View {
    @Binding var currencyCode: String

    var body: some View {
        Picker("Currency", selection: $currencyCode) {
            ForEach(SupportedCurrency.allCases) { currency in
                Text(currency.displayName).tag(currency.rawValue)
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 150)
    }
}

// MARK: - Reusable Step Buttons

/// Reusable continue + skip buttons for onboarding steps.
struct OnboardingStepButtons: View {
    let continueLabel: String
    var continueDisabled: Bool = false
    var onContinue: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button {
                onContinue()
            } label: {
                Text(continueLabel)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(continueDisabled)

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
    OnboardingCurrencyStep(
        currencyCode: .constant("GBP"),
        onContinue: {},
        onSkip: {}
    )
}
