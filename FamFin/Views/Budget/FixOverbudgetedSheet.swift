import SwiftUI
import SwiftData

/// Sheet that helps the user resolve an overbudgeted state by reducing category budgets.
///
/// Each "Reduce" tap persists immediately — partial fixes are preserved if the user cancels.
/// When the overbudgeted amount reaches zero, a success state displays briefly before auto-dismissing.
struct FixOverbudgetedSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    let month: Date
    let initialOverbudgetedAmount: Decimal
    let onApplied: () -> Void

    @State private var remaining: Decimal
    @State private var adjustedBudgets: [String: Decimal] = [:]
    @State private var adjustedAvailable: [String: Decimal] = [:]
    @State private var showSuccess = false
    @State private var otherCategoriesExpanded = false

    init(month: Date, initialOverbudgetedAmount: Decimal, onApplied: @escaping () -> Void) {
        self.month = month
        self.initialOverbudgetedAmount = initialOverbudgetedAmount
        self.onApplied = onApplied
        self._remaining = State(initialValue: initialOverbudgetedAmount)
    }

    // MARK: - Computed

    private var budgetableCategories: [Category] {
        allCategories.filter { !$0.isHeader && !$0.isSystem && !$0.isHidden }
    }

    /// Categories with positive available balance — safe to reduce.
    private var reducibleCategories: [Category] {
        budgetableCategories
            .filter { effectiveAvailable(for: $0) > 0 }
            .sorted { effectiveAvailable(for: $0) > effectiveAvailable(for: $1) }
    }

    /// Categories with zero or negative available — shown in collapsed section.
    private var otherCategories: [Category] {
        budgetableCategories.filter { effectiveAvailable(for: $0) <= 0 }
    }

    private func effectiveAvailable(for category: Category) -> Decimal {
        let key = "\(category.persistentModelID)"
        return adjustedAvailable[key] ?? category.available(through: month)
    }

    private func effectiveBudgeted(for category: Category) -> Decimal {
        let key = "\(category.persistentModelID)"
        return adjustedBudgets[key] ?? category.budgeted(in: month)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if showSuccess {
                    successView
                } else {
                    mainContent
                }
            }
            .navigationTitle("Fix Overbudgeted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !showSuccess {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        List {
            headerSection

            if !reducibleCategories.isEmpty {
                reduceSection
            } else {
                noReducibleSection
            }

            if !otherCategories.isEmpty {
                otherSection
            }
        }
    }

    private var headerSection: some View {
        Section {
            VStack(spacing: 4) {
                GBPText(amount: remaining, font: .title2.bold())
                    .contentTransition(reduceMotion ? .identity : .numericText())
                Text("still overbudgeted")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(formatGBP(remaining, currencyCode: currencyCode)) still overbudgeted")
        }
        .listRowBackground(Color.red.opacity(0.08))
    }

    private var reduceSection: some View {
        Section("Reduce from") {
            ForEach(reducibleCategories) { category in
                reduceCategoryRow(category)
            }
        }
    }

    private var noReducibleSection: some View {
        Section {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("No categories have available funds to reduce.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var otherSection: some View {
        Section {
            DisclosureGroup(
                "Other categories (\(otherCategories.count))",
                isExpanded: $otherCategoriesExpanded
            ) {
                ForEach(otherCategories) { category in
                    HStack {
                        Text(category.emoji)
                            .accessibilityHidden(true)
                        Text(category.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        let avail = effectiveAvailable(for: category)
                        Text(formatGBP(avail, currencyCode: currencyCode))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(avail < 0 ? .red : .secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: - Category Row

    private func reduceCategoryRow(_ category: Category) -> some View {
        let avail = effectiveAvailable(for: category)
        let reduceAmount = min(avail, remaining)

        return HStack {
            Text(category.emoji)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text("Available: \(formatGBP(avail, currencyCode: currencyCode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Button("Reduce") {
                reduceCategory(category, by: reduceAmount)
            }
            .font(.subheadline)
            .bold()
            .foregroundStyle(.red)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.15))
            .clipShape(.rect(cornerRadius: 8))
            .accessibilityHint("Reduces budget by \(formatGBP(reduceAmount, currencyCode: currencyCode))")
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Reduce Logic

    private func reduceCategory(_ category: Category, by amount: Decimal) {
        let catKey = "\(category.persistentModelID)"
        let currentBudgeted = effectiveBudgeted(for: category)
        let currentAvailable = effectiveAvailable(for: category)
        let newBudgeted = currentBudgeted - amount

        // Update local state
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            adjustedBudgets[catKey] = newBudgeted
            adjustedAvailable[catKey] = currentAvailable - amount
            remaining -= amount
        }

        // Persist to SwiftData
        persistBudgetChange(for: category, newBudgeted: newBudgeted)
        HapticManager.light()

        // Check for completion
        if remaining <= 0 {
            HapticManager.success()
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                showSuccess = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                onApplied()
                dismiss()
            }
        }
    }

    // MARK: - Persistence

    private func persistBudgetChange(for category: Category, newBudgeted: Decimal) {
        let calendar = Calendar.current

        let bmDescriptor = FetchDescriptor<BudgetMonth>()
        let allBMs = (try? modelContext.fetch(bmDescriptor)) ?? []
        var bm = allBMs.first(where: {
            calendar.isDate($0.month, equalTo: month, toGranularity: .month)
        })
        if bm == nil {
            let newBM = BudgetMonth(month: month)
            modelContext.insert(newBM)
            bm = newBM
        }

        guard let budgetMonth = bm else { return }
        let catID = category.persistentModelID
        let allocDescriptor = FetchDescriptor<BudgetAllocation>()
        let allAllocations = (try? modelContext.fetch(allocDescriptor)) ?? []
        let existing = allAllocations.first(where: {
            $0.category?.persistentModelID == catID &&
            $0.budgetMonth?.persistentModelID == budgetMonth.persistentModelID
        })

        if let existing {
            if newBudgeted == .zero {
                modelContext.delete(existing)
            } else {
                existing.budgeted = newBudgeted
            }
        } else if newBudgeted != .zero {
            let allocation = BudgetAllocation(budgeted: newBudgeted)
            allocation.category = category
            allocation.budgetMonth = bm
            modelContext.insert(allocation)
        }

        try? modelContext.save()

    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text("All balanced")
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("All balanced")
    }
}
