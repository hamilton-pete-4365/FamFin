import SwiftUI
import SwiftData

/// Main coordinator for the interactive onboarding flow.
/// Manages step navigation and provides skip/complete actions to child steps.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(CurrencySettings.key) private var currencyCode = "GBP"

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentStep = 0

    /// The set of category group names the user has chosen to include.
    /// All are enabled by default; the categories step can toggle them.
    @State private var enabledCategoryGroups: Set<String> = Set(
        DefaultCategories.all.map(\.name)
    )

    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressIndicator(
                currentStep: currentStep,
                totalSteps: totalSteps
            )

            TabView(selection: $currentStep) {
                OnboardingWelcomeStep(
                    onContinue: advanceStep,
                    onSkip: skipOnboarding
                )
                .tag(0)

                OnboardingCurrencyStep(
                    currencyCode: $currencyCode,
                    onContinue: advanceStep,
                    onSkip: skipOnboarding
                )
                .tag(1)

                OnboardingAccountsStep(
                    onContinue: advanceStep,
                    onSkip: skipOnboarding
                )
                .tag(2)

                OnboardingCategoriesStep(
                    enabledGroups: $enabledCategoryGroups,
                    onContinue: {
                        seedSelectedCategories()
                        advanceStep()
                    },
                    onSkip: skipOnboarding
                )
                .tag(3)

                OnboardingCompletionStep(
                    onFinish: completeOnboarding
                )
                .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? .none : .easeInOut, value: currentStep)
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Navigation

    private func advanceStep() {
        guard currentStep < totalSteps - 1 else { return }
        withAnimation(reduceMotion ? .none : .easeInOut) {
            currentStep += 1
        }
    }

    // MARK: - Skip / Complete

    /// Skip onboarding entirely: seed all default categories and mark complete.
    private func skipOnboarding() {
        DefaultCategories.seedIfNeeded(context: modelContext)
        hasCompletedOnboarding = true
    }

    /// Called after the user finishes the completion step.
    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    // MARK: - Category Seeding

    /// Seeds only the category groups the user selected during onboarding.
    private func seedSelectedCategories() {
        let descriptor = FetchDescriptor<Category>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []

        // Ensure the system "To Budget" category exists
        let hasSystem = existing.contains { $0.isSystem && $0.name == DefaultCategories.toBudgetName }
        if !hasSystem {
            let toBudget = Category(
                name: DefaultCategories.toBudgetName,
                emoji: "💰",
                isHeader: false,
                isSystem: true,
                sortOrder: -1
            )
            modelContext.insert(toBudget)
        }

        // Seed only enabled header groups
        var headerIndex = 0
        for headerDef in DefaultCategories.all {
            guard enabledCategoryGroups.contains(headerDef.name) else { continue }

            let header = Category(
                name: headerDef.name,
                emoji: headerDef.emoji,
                isHeader: true,
                sortOrder: headerIndex
            )
            modelContext.insert(header)

            for (subIndex, subDef) in headerDef.subcategories.enumerated() {
                let sub = Category(
                    name: subDef.name,
                    emoji: subDef.emoji,
                    isHeader: false,
                    sortOrder: subIndex
                )
                sub.parent = header
                modelContext.insert(sub)
            }

            headerIndex += 1
        }

        try? modelContext.save()
    }
}

// MARK: - Progress Indicator

/// A row of dots showing the user's position in the onboarding flow.
struct OnboardingProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == currentStep ? 10 : 8, height: index == currentStep ? 10 : 8)
                    .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: currentStep)
            }
        }
        .padding(.top)
        .padding(.bottom, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep + 1) of \(totalSteps)")
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [
            Account.self,
            Category.self,
            BudgetMonth.self,
        ], inMemory: true)
}
