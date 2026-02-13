import SwiftUI
import SwiftData

/// Sheet for setting the budgeted amount for a category in a specific month.
/// Tap a category row in the Budget tab to open this.
struct EditBudgetAmountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allBudgetMonths: [BudgetMonth]

    let category: Category
    let month: Date

    @State private var amountText = ""
    @State private var hasLoaded = false
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    var body: some View {
        NavigationStack {
            Form {
                // Category info
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .font(.headline)
                        if let parentName = category.parent?.name {
                            Text(parentName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Budget amount input
                Section("Budget for \(month, format: .dateTime.month(.wide).year())") {
                    HStack {
                        Text((SupportedCurrency(rawValue: currencyCode) ?? .gbp).symbol)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .font(.title2)
                            .keyboardType(.decimalPad)
                    }
                }

                // Context: current available balance
                Section("Envelope Balance") {
                    HStack {
                        Text("Available")
                        Spacer()
                        GBPText(amount: category.available(through: month))
                    }
                    HStack {
                        Text("Activity this month")
                        Spacer()
                        GBPText(amount: category.activity(in: month), font: .headline)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Set Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear {
                guard !hasLoaded else { return }
                hasLoaded = true
                // Load existing budgeted amount
                if let existing = existingAllocation() {
                    if existing.budgeted != .zero {
                        amountText = "\(existing.budgeted)"
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func existingAllocation() -> BudgetAllocation? {
        let calendar = Calendar.current
        let catID = category.persistentModelID
        guard let bm = allBudgetMonths.first(where: {
            calendar.isDate($0.month, equalTo: month, toGranularity: .month)
        }) else { return nil }
        return bm.allocations.first(where: { $0.category?.persistentModelID == catID })
    }

    private func save() {
        let amount = Decimal(string: amountText) ?? Decimal.zero
        let calendar = Calendar.current
        let catID = category.persistentModelID

        // Find or create BudgetMonth
        var bm = allBudgetMonths.first(where: {
            calendar.isDate($0.month, equalTo: month, toGranularity: .month)
        })
        if bm == nil {
            let newBM = BudgetMonth(month: month)
            modelContext.insert(newBM)
            bm = newBM
        }

        // Find or create allocation — use persistentModelID for reliable matching
        if let existing = bm!.allocations.first(where: { $0.category?.persistentModelID == catID }) {
            existing.budgeted = amount
        } else {
            let allocation = BudgetAllocation(budgeted: amount)
            allocation.category = category
            allocation.budgetMonth = bm
            modelContext.insert(allocation)
        }

        // Persist changes
        try? modelContext.save()

        dismiss()
    }
}
