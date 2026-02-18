import Foundation
import SwiftData

/// Fetches budget and account data from the shared SwiftData container for widget display.
/// This runs in the widget extension process and creates its own ModelContainer.
struct WidgetDataProvider {

    /// Snapshot of data needed by all widget families.
    struct WidgetData {
        var toBudgetAmount: Decimal = .zero
        var totalBudgeted: Decimal = .zero
        var totalIncome: Decimal = .zero
        var accounts: [AccountSnapshot] = []
        var overspentCategories: [CategorySnapshot] = []
        var topCategories: [CategorySnapshot] = []
        var currencyCode: String = "GBP"
    }

    struct AccountSnapshot {
        let name: String
        let balance: Decimal
        let type: String
    }

    struct CategorySnapshot {
        let name: String
        let emoji: String
        let available: Decimal
    }

    /// Load widget data from the shared SwiftData store.
    static func loadData() -> WidgetData {
        var data = WidgetData()

        // Read currency setting from shared UserDefaults (App Group)
        if let sharedDefaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier) {
            data.currencyCode = sharedDefaults.string(forKey: "selectedCurrencyCode") ?? "GBP"
        } else {
            data.currencyCode = UserDefaults.standard.string(forKey: "selectedCurrencyCode") ?? "GBP"
        }

        guard let container = try? SharedModelContainer.makeWidgetContainer() else {
            return data
        }

        let context = ModelContext(container)
        let currentMonth = normalizedCurrentMonth()

        // Fetch accounts
        guard let accounts = try? context.fetch(FetchDescriptor<Account>()) else {
            return data
        }

        data.accounts = accounts
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { AccountSnapshot(name: $0.name, balance: $0.balance, type: $0.type.rawValue) }

        // Fetch the "To Budget" system category
        let categoryDescriptor = FetchDescriptor<Category>()
        guard let allCategories = try? context.fetch(categoryDescriptor) else {
            return data
        }

        let toBudgetCategory = allCategories.first { $0.isSystem && $0.name == "To Budget" }

        // Calculate "To Budget" amount
        if let toBudgetCategory {
            data.toBudgetAmount = BudgetCalculator.toBudgetAvailable(
                through: currentMonth,
                toBudgetCategory: toBudgetCategory,
                accounts: accounts,
                context: context
            )
        }

        // Calculate total income for the current month to determine budget utilization
        let endOfMonth = endOfMonth(currentMonth)
        var totalIncome: Decimal = .zero
        for account in accounts where account.isBudget {
            for transaction in account.transactions {
                guard transaction.date >= currentMonth && transaction.date < endOfMonth else { continue }
                if transaction.type == .income && transaction.category == nil {
                    totalIncome += transaction.amount
                }
            }
            for transaction in account.incomingTransfers {
                guard transaction.type == .transfer else { continue }
                guard transaction.date >= currentMonth && transaction.date < endOfMonth else { continue }
                guard transaction.account?.isBudget == false else { continue }
                if transaction.category == nil {
                    totalIncome += transaction.amount
                }
            }
        }
        data.totalIncome = totalIncome

        // Calculate total budgeted this month
        let budgetMonthDescriptor = FetchDescriptor<BudgetMonth>()
        if let budgetMonths = try? context.fetch(budgetMonthDescriptor) {
            let calendar = Calendar.current
            let currentComps = calendar.dateComponents([.year, .month], from: currentMonth)
            for bm in budgetMonths {
                let bmComps = calendar.dateComponents([.year, .month], from: bm.month)
                if currentComps.year == bmComps.year && currentComps.month == bmComps.month {
                    data.totalBudgeted = bm.totalBudgeted
                    break
                }
            }
        }

        // Build category snapshots for subcategories (non-header, non-system)
        let subcategories = allCategories.filter { !$0.isHeader && !$0.isSystem }

        var overspent: [CategorySnapshot] = []
        var topRemaining: [CategorySnapshot] = []

        for cat in subcategories {
            let available = cat.available(through: currentMonth)
            let snapshot = CategorySnapshot(name: cat.name, emoji: cat.emoji, available: available)
            if available < .zero {
                overspent.append(snapshot)
            } else if available > .zero {
                topRemaining.append(snapshot)
            }
        }

        // Sort overspent by most overspent first (most negative)
        data.overspentCategories = overspent.sorted { $0.available < $1.available }

        // Sort top categories by highest remaining first
        data.topCategories = topRemaining.sorted { $0.available > $1.available }

        return data
    }

    // MARK: - Helpers

    private static func normalizedCurrentMonth() -> Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: comps) ?? Date()
    }

    private static func endOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let firstOfMonth = calendar.date(from: comps),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth) else {
            return date
        }
        return nextMonth
    }
}
