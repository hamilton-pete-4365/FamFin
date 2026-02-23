import SwiftUI
import SwiftData

/// Sheet that helps the user cover overspent categories by moving budget from healthy ones.
///
/// The user selects which overspent categories to cover and which source categories to draw from.
/// Pre-filled suggestions calculate reasonable amounts. All changes are batched and persisted
/// on "Apply" — source budgets are reduced and overspent budgets are increased atomically.
struct FixOverspentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    let month: Date
    let onApplied: () -> Void

    /// Which overspent categories the user wants to cover.
    @State private var selectedOverspent: Set<String> = []
    /// Which source categories the user wants to draw from.
    @State private var selectedSources: Set<String> = []
    /// Amount to take from each selected source category.
    @State private var sourceAmounts: [String: Decimal] = [:]
    @State private var showSuccess = false

    // MARK: - Computed

    private var budgetableCategories: [Category] {
        allCategories.filter { !$0.isHeader && !$0.isSystem && !$0.isHidden }
    }

    /// Categories with negative available (overspent).
    var overspentCategories: [Category] {
        budgetableCategories
            .filter { $0.available(through: month) < 0 }
            .sorted { $0.name < $1.name }
    }

    /// Categories with positive available (can be a source of funds).
    var sourceCategories: [Category] {
        budgetableCategories
            .filter { $0.available(through: month) > 0 }
            .sorted { $0.available(through: month) > $1.available(through: month) }
    }

    /// Total deficit of selected overspent categories.
    private var totalNeeded: Decimal {
        overspentCategories
            .filter { selectedOverspent.contains("\($0.persistentModelID)") }
            .reduce(Decimal.zero) { $0 + (-$1.available(through: month)) }
    }

    /// Total committed from selected sources.
    private var totalProvided: Decimal {
        selectedSources.reduce(Decimal.zero) { total, key in
            total + (sourceAmounts[key] ?? 0)
        }
    }

    /// Remaining gap between what's needed and what's provided.
    private var remainingGap: Decimal {
        max(totalNeeded - totalProvided, 0)
    }

    /// Whether the user has committed enough funds to cover all selected overspent categories.
    private var canApply: Bool {
        totalNeeded > 0 && totalProvided >= totalNeeded
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
            .navigationTitle("Fix Overspent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !showSuccess {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !showSuccess {
                        Button("Apply") { applyMoves() }
                            .bold()
                            .disabled(!canApply)
                    }
                }
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        List {
            summarySection
            overspentSection

            if !sourceCategories.isEmpty {
                moveFromSection
            } else {
                noSourcesSection
            }
        }
    }

    private var summarySection: some View {
        Section {
            VStack(spacing: 8) {
                HStack {
                    Text("Need")
                        .font(.subheadline)
                    Spacer()
                    Text(formatGBP(totalNeeded, currencyCode: currencyCode))
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(totalNeeded > 0 ? .red : .secondary)
                }

                HStack {
                    Text("Covered")
                        .font(.subheadline)
                    Spacer()
                    Text(formatGBP(totalProvided, currencyCode: currencyCode))
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(totalProvided > 0 ? Color.accentColor : .secondary)
                }

                if remainingGap > 0 && totalNeeded > 0 {
                    HStack {
                        Text("Remaining")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatGBP(remainingGap, currencyCode: currencyCode))
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .contentTransition(reduceMotion ? .identity : .numericText())
        }
    }

    // MARK: - Overspent Section

    private var overspentSection: some View {
        Section("Overspent") {
            ForEach(overspentCategories) { category in
                overspentRow(category)
            }
        }
    }

    private func overspentRow(_ category: Category) -> some View {
        let key = "\(category.persistentModelID)"
        let deficit = -category.available(through: month)
        let isSelected = selectedOverspent.contains(key)

        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedOverspent.remove(key)
                } else {
                    selectedOverspent.insert(key)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .red : .secondary)

                Text(category.emoji)
                    .accessibilityHidden(true)

                Text(category.name)
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer()

                Text(formatGBP(-deficit, currencyCode: currencyCode))
                    .font(.subheadline)
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(.red)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.name), overspent by \(formatGBP(deficit, currencyCode: currencyCode))")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to \(isSelected ? "deselect" : "select")")
    }

    // MARK: - Move From Section

    private var moveFromSection: some View {
        Section("Move from") {
            ForEach(sourceCategories) { category in
                sourceRow(category)
            }
        }
    }

    private func sourceRow(_ category: Category) -> some View {
        let key = "\(category.persistentModelID)"
        let avail = category.available(through: month)
        let isSelected = selectedSources.contains(key)
        let amount = sourceAmounts[key] ?? 0

        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedSources.remove(key)
                    sourceAmounts.removeValue(forKey: key)
                } else {
                    selectedSources.insert(key)
                    // Pre-fill with a suggested amount
                    let suggestion = min(avail, remainingGap)
                    sourceAmounts[key] = suggestion > 0 ? suggestion : avail
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

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

                if isSelected {
                    Text(formatGBP(amount, currencyCode: currencyCode))
                        .font(.subheadline)
                        .bold()
                        .monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.name), available \(formatGBP(avail, currencyCode: currencyCode))")
        .accessibilityValue(isSelected ? "Selected, moving \(formatGBP(amount, currencyCode: currencyCode))" : "Not selected")
        .accessibilityHint("Double tap to \(isSelected ? "deselect" : "select")")
    }

    private var noSourcesSection: some View {
        Section {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("No categories have available funds to move.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Apply

    private func applyMoves() {
        let calendar = Calendar.current

        // Find or create BudgetMonth
        let bmDescriptor = FetchDescriptor<BudgetMonth>()
        let allBMs = (try? modelContext.fetch(bmDescriptor)) ?? []
        var budgetMonth = allBMs.first(where: {
            calendar.isDate($0.month, equalTo: month, toGranularity: .month)
        })
        if budgetMonth == nil {
            let newBM = BudgetMonth(month: month)
            modelContext.insert(newBM)
            budgetMonth = newBM
        }
        guard let bm = budgetMonth else { return }

        let allocDescriptor = FetchDescriptor<BudgetAllocation>()
        let allAllocations = (try? modelContext.fetch(allocDescriptor)) ?? []

        // 1. Reduce source categories
        for key in selectedSources {
            guard let amount = sourceAmounts[key], amount > 0 else { continue }
            guard let source = budgetableCategories.first(where: { "\($0.persistentModelID)" == key }) else { continue }
            let currentBudgeted = source.budgeted(in: month)
            updateAllocation(
                for: source,
                newBudgeted: currentBudgeted - amount,
                budgetMonth: bm,
                allAllocations: allAllocations
            )
        }

        // 2. Increase overspent categories — distribute funds, most negative first
        var remainingFunds = totalProvided
        let selectedOverspentCats = overspentCategories
            .filter { selectedOverspent.contains("\($0.persistentModelID)") }
            .sorted { $0.available(through: month) < $1.available(through: month) }

        for category in selectedOverspentCats {
            let deficit = -category.available(through: month)
            let coverAmount = min(deficit, remainingFunds)
            let currentBudgeted = category.budgeted(in: month)
            updateAllocation(
                for: category,
                newBudgeted: currentBudgeted + coverAmount,
                budgetMonth: bm,
                allAllocations: allAllocations
            )
            remainingFunds -= coverAmount
        }

        try? modelContext.save()
        HapticManager.medium()

        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            showSuccess = true
        }
        HapticManager.success()

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            onApplied()
            dismiss()
        }
    }

    private func updateAllocation(
        for category: Category,
        newBudgeted: Decimal,
        budgetMonth: BudgetMonth,
        allAllocations: [BudgetAllocation]
    ) {
        let catID = category.persistentModelID
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
            allocation.budgetMonth = budgetMonth
            modelContext.insert(allocation)
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text("All covered")
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("All overspent categories covered")
    }
}
