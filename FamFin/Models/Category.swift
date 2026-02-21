import Foundation
import SwiftData

@Model
final class Category {
    var name: String = ""
    var emoji: String = "📁"
    var isHeader: Bool = false          // true = grouping header, false = budgetable subcategory
    var isSystem: Bool = false          // true = system category (e.g. "To Budget"), not user-editable
    var sortOrder: Int = 0          // ordering within its level (among siblings)
    var isHidden: Bool = false       // soft-hide: excluded from budget and pickers, data retained

    // Parent: only subcategories have a parent (headers have nil)
    var parent: Category?

    // Children: only headers have children (subcategories have empty array)
    @Relationship(deleteRule: .cascade, inverse: \Category.parent)
    var children: [Category] = []

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction] = []

    @Relationship(deleteRule: .cascade, inverse: \BudgetAllocation.category)
    var allocations: [BudgetAllocation] = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringTransaction.category)
    var recurringTransactions: [RecurringTransaction] = []

    // Keep old field for migration — SwiftData won't crash if it exists in DB
    private var group: String?

    init(name: String, emoji: String = "📁", isHeader: Bool = false, isSystem: Bool = false, sortOrder: Int = 0) {
        self.name = name
        self.emoji = emoji
        self.isHeader = isHeader
        self.isSystem = isSystem
        self.sortOrder = sortOrder
    }

    /// Sorted children for display (includes hidden — used by ManageCategoriesView)
    var sortedChildren: [Category] {
        children.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Visible (non-hidden) sorted children for budget display and pickers
    var visibleSortedChildren: [Category] {
        children.filter { !$0.isHidden }.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Total number of transactions linked to this category (or its children if a header)
    var transactionCount: Int {
        if isHeader {
            return children.reduce(0) { $0 + $1.transactions.count }
        }
        return transactions.count
    }

    // MARK: - Activity (transaction impact on this category)

    /// Net activity in this category for a given month.
    /// Expenses reduce the balance, income increases it.
    /// Cross-boundary transfers also affect the balance:
    ///   Budget → Tracking = outflow (reduces balance, like an expense)
    ///   Tracking → Budget = inflow (increases balance, like income)
    func activity(in month: Date) -> Decimal {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: month)
        guard let startOfMonth = calendar.date(from: comps),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return Decimal.zero
        }
        var net = Decimal.zero
        for transaction in transactions {
            guard transaction.date >= startOfMonth && transaction.date < endOfMonth else { continue }
            switch transaction.type {
            case .expense:
                guard transaction.account?.isBudget == true else { continue }
                net -= transaction.amount
            case .income:
                guard transaction.account?.isBudget == true else { continue }
                net += transaction.amount
            case .transfer:
                // Only cross-boundary transfers with a category affect budget
                guard transaction.transferNeedsCategory else { continue }
                if transaction.account?.isBudget == true {
                    // Budget → Tracking: money leaving the budget system
                    net -= transaction.amount
                } else {
                    // Tracking → Budget: money entering the budget system
                    net += transaction.amount
                }
            }
        }
        return net
    }

    /// Cumulative net activity from all time up to and including the given month.
    /// Expenses reduce the balance, income assigned to a category increases it.
    /// Cross-boundary transfers also affect the balance.
    func cumulativeActivity(through month: Date) -> Decimal {
        let endOfMonth = Self.endOfMonth(month)
        var net = Decimal.zero
        for transaction in transactions {
            guard transaction.date < endOfMonth else { continue }
            switch transaction.type {
            case .expense:
                guard transaction.account?.isBudget == true else { continue }
                net -= transaction.amount
            case .income:
                guard transaction.account?.isBudget == true else { continue }
                net += transaction.amount
            case .transfer:
                guard transaction.transferNeedsCategory else { continue }
                if transaction.account?.isBudget == true {
                    net -= transaction.amount
                } else {
                    net += transaction.amount
                }
            }
        }
        return net
    }

    // MARK: - Budgeted amounts (allocations TO this category)

    /// Cumulative budgeted from all time up to and including the given month
    func cumulativeBudgeted(through month: Date) -> Decimal {
        let endOfMonth = Self.endOfMonth(month)
        return allocations
            .filter { allocation in
                guard let allocMonth = allocation.budgetMonth?.month else { return false }
                return allocMonth < endOfMonth
            }
            .reduce(Decimal.zero) { $0 + $1.budgeted }
    }

    /// Budgeted in a specific month
    func budgeted(in month: Date) -> Decimal {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: month)
        guard let startOfMonth = calendar.date(from: comps),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return Decimal.zero
        }
        return allocations
            .filter { allocation in
                guard let allocMonth = allocation.budgetMonth?.month else { return false }
                return allocMonth >= startOfMonth && allocMonth < endOfMonth
            }
            .reduce(Decimal.zero) { $0 + $1.budgeted }
    }

    // MARK: - Available balance

    /// Available balance = cumulative budgeted + cumulative activity (the envelope balance).
    /// Activity is negative for expenses, positive for income assigned to this category.
    /// This is for normal (non-system) categories.
    func available(through month: Date) -> Decimal {
        cumulativeBudgeted(through: month) + cumulativeActivity(through: month)
    }

    // MARK: - Historical averages

    /// Average monthly spending (absolute value of activity) over the last N months before the given month.
    /// Only counts months where there was any activity, to avoid diluting the average with zero months.
    /// Returns zero if no history exists.
    func averageMonthlySpending(before month: Date, months count: Int = 12) -> Decimal {
        let calendar = Calendar.current
        var totals: [Decimal] = []

        for offset in 1...count {
            guard let pastMonth = calendar.date(byAdding: .month, value: -offset, to: month) else { continue }
            let monthActivity = activity(in: pastMonth)
            // Activity is negative for spending — only include months with net outflow.
            // Positive activity (income/refunds) is excluded to avoid polluting the spending average.
            if monthActivity < .zero {
                totals.append(-monthActivity)
            }
        }

        guard !totals.isEmpty else { return Decimal.zero }
        return totals.reduce(Decimal.zero, +) / Decimal(totals.count)
    }

    /// Average monthly budgeted over the last N months before the given month.
    /// Only counts months where there was a budget set, to avoid diluting with zero months.
    func averageMonthlyBudgeted(before month: Date, months count: Int = 12) -> Decimal {
        let calendar = Calendar.current
        var totals: [Decimal] = []

        for offset in 1...count {
            guard let pastMonth = calendar.date(byAdding: .month, value: -offset, to: month) else { continue }
            let monthBudget = budgeted(in: pastMonth)
            if monthBudget != .zero {
                totals.append(monthBudget)
            }
        }

        guard !totals.isEmpty else { return Decimal.zero }
        return totals.reduce(Decimal.zero, +) / Decimal(totals.count)
    }

    // MARK: - Helpers

    /// Helper: get the first moment of the month after the given month
    static func endOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let firstOfMonth = calendar.date(from: comps),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth) else {
            return date
        }
        return nextMonth
    }
}
