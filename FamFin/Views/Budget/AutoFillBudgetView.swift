import SwiftUI
import SwiftData

/// Sheet that lets the user auto-fill all category budgets for a given month
/// using one of the Quick Fill hint sources (last month budgeted/spent, 12-month averages).
struct AutoFillBudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    let month: Date
    /// Called after applying so the parent can refresh its local caches.
    let onApplied: () -> Void

    @State private var selectedSource: HintSource = .lastBudgeted
    @State private var overwriteExisting = false

    // MARK: - Hint Sources

    enum HintSource: String, CaseIterable, Identifiable {
        case lastBudgeted = "Last Month Budgeted"
        case lastSpent = "Last Month Spent"
        case avgBudgeted = "12-Month Avg Budgeted"
        case avgSpent = "12-Month Avg Spent"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .lastBudgeted: "Copy each category's budget from last month."
            case .lastSpent: "Set each budget to what was actually spent last month."
            case .avgBudgeted: "Use the average budget over the past 12 months."
            case .avgSpent: "Use the average spending over the past 12 months."
            }
        }

        var systemImage: String {
            switch self {
            case .lastBudgeted: "doc.on.doc"
            case .lastSpent: "cart"
            case .avgBudgeted: "chart.bar"
            case .avgSpent: "chart.line.downtrend.xyaxis"
            }
        }
    }

    // MARK: - Computed

    private var budgetableCategories: [Category] {
        allCategories.filter { !$0.isHeader && !$0.isSystem && !$0.isHidden }
    }

    /// Preview of what will be applied: (category, hint amount, already budgeted).
    private var preview: [(category: Category, hint: Decimal, current: Decimal)] {
        budgetableCategories.compactMap { cat in
            let hint = hintAmount(for: cat)
            let current = cat.budgeted(in: month)
            // Skip categories with no hint data
            guard hint != .zero else { return nil }
            // If not overwriting, skip categories that already have a budget
            if !overwriteExisting && current != .zero { return nil }
            return (category: cat, hint: hint, current: current)
        }
    }

    private var totalHint: Decimal {
        preview.reduce(.zero) { $0 + $1.hint }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                sourceSection
                overwriteSection
                previewSection
            }
            .navigationTitle("Auto-Fill Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { applyHints() }
                        .bold()
                        .disabled(preview.isEmpty)
                }
            }
        }
    }

    // MARK: - Sections

    private var sourceSection: some View {
        Section {
            ForEach(HintSource.allCases) { source in
                Button {
                    selectedSource = source
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: source.systemImage)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text(source.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if selectedSource == source {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                                .bold()
                        }
                    }
                }
                .tint(.primary)
            }
        } header: {
            Text("Source")
        }
    }

    private var overwriteSection: some View {
        Section {
            Toggle("Overwrite existing budgets", isOn: $overwriteExisting)
        } footer: {
            Text(overwriteExisting
                 ? "All categories will be updated, replacing any amounts already set."
                 : "Only categories with no budget this month will be filled.")
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        Section {
            if preview.isEmpty {
                ContentUnavailableView {
                    Label("Nothing to Fill", systemImage: "tray")
                } description: {
                    if overwriteExisting {
                        Text("No categories have hint data for this source.")
                    } else {
                        Text("All categories already have a budget set, or no hint data is available.")
                    }
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(preview, id: \.category.persistentModelID) { item in
                    HStack {
                        Text(item.category.emoji)
                            .accessibilityHidden(true)
                        Text(item.category.name)
                            .font(.subheadline)
                            .lineLimit(1)

                        Spacer()

                        if item.current != .zero {
                            Text(formatGBP(item.current, currencyCode: currencyCode))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .strikethrough()
                                .accessibilityLabel("currently \(formatGBP(item.current, currencyCode: currencyCode))")

                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }

                        Text(formatGBP(item.hint, currencyCode: currencyCode))
                            .font(.subheadline)
                            .bold()
                            .monospacedDigit()
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityElement(children: .combine)
                }

                // Total row
                HStack {
                    Text("Total")
                        .font(.subheadline)
                        .bold()
                    Spacer()
                    Text(formatGBP(totalHint, currencyCode: currencyCode))
                        .font(.subheadline)
                        .bold()
                        .monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Preview (\(preview.count) \(preview.count == 1 ? "category" : "categories"))")
        }
    }

    // MARK: - Hint Calculation

    private func hintAmount(for category: Category) -> Decimal {
        switch selectedSource {
        case .lastBudgeted:
            guard let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: month) else { return .zero }
            return category.budgeted(in: lastMonth)
        case .lastSpent:
            guard let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: month) else { return .zero }
            return -category.activity(in: lastMonth)
        case .avgBudgeted:
            return category.averageMonthlyBudgeted(before: month, months: 12)
        case .avgSpent:
            return category.averageMonthlySpending(before: month, months: 12)
        }
    }

    // MARK: - Apply

    private func applyHints() {
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

        // Fetch all existing allocations once
        let allocDescriptor = FetchDescriptor<BudgetAllocation>()
        let allAllocations = (try? modelContext.fetch(allocDescriptor)) ?? []

        for item in preview {
            let catID = item.category.persistentModelID
            let existing = allAllocations.first(where: {
                $0.category?.persistentModelID == catID &&
                $0.budgetMonth?.persistentModelID == bm.persistentModelID
            })

            if let existing {
                if item.hint == .zero {
                    modelContext.delete(existing)
                } else {
                    existing.budgeted = item.hint
                }
            } else if item.hint != .zero {
                let allocation = BudgetAllocation(budgeted: item.hint)
                allocation.category = item.category
                allocation.budgetMonth = bm
                modelContext.insert(allocation)
            }
        }

        try? modelContext.save()
        HapticManager.medium()

        onApplied()
        dismiss()
    }
}
