import Foundation
import SwiftData

@Model
final class Category {
    var name: String
    var emoji: String
    var isHeader: Bool          // true = grouping header, false = budgetable subcategory
    var isSystem: Bool          // true = system category (e.g. "To Budget"), not user-editable
    var sortOrder: Int          // ordering within its level (among siblings)

    // Parent: only subcategories have a parent (headers have nil)
    var parent: Category?

    // Children: only headers have children (subcategories have empty array)
    @Relationship(deleteRule: .cascade, inverse: \Category.parent)
    var children: [Category] = []

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction] = []

    @Relationship(deleteRule: .cascade, inverse: \BudgetAllocation.category)
    var allocations: [BudgetAllocation] = []

    // Keep old field for migration — SwiftData won't crash if it exists in DB
    private var group: String?

    init(name: String, emoji: String = "📁", isHeader: Bool = false, isSystem: Bool = false, sortOrder: Int = 0) {
        self.name = name
        self.emoji = emoji
        self.isHeader = isHeader
        self.isSystem = isSystem
        self.sortOrder = sortOrder
    }

    /// Sorted children for display
    var sortedChildren: [Category] {
        children.sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Activity (transaction impact on this category)

    /// Net activity in this category for a given month (Budget accounts only).
    /// Expenses reduce the balance, income increases it.
    func activity(in month: Date) -> Decimal {
        let calendar = Calendar.current
        var net = Decimal.zero
        for transaction in transactions {
            guard transaction.account?.isBudget == true else { continue }
            guard calendar.isDate(transaction.date, equalTo: month, toGranularity: .month) else { continue }
            switch transaction.type {
            case .expense:
                net -= transaction.amount
            case .income:
                net += transaction.amount
            case .transfer:
                break  // transfers don't affect category activity
            }
        }
        return net
    }

    /// Cumulative net activity from all time up to and including the given month.
    /// Expenses reduce the balance, income assigned to a category increases it.
    func cumulativeActivity(through month: Date) -> Decimal {
        let endOfMonth = Self.endOfMonth(month)
        var net = Decimal.zero
        for transaction in transactions {
            guard transaction.account?.isBudget == true else { continue }
            guard transaction.date < endOfMonth else { continue }
            switch transaction.type {
            case .expense:
                net -= transaction.amount
            case .income:
                net += transaction.amount
            case .transfer:
                break
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
        return allocations
            .filter { allocation in
                guard let allocMonth = allocation.budgetMonth?.month else { return false }
                return calendar.isDate(allocMonth, equalTo: month, toGranularity: .month)
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
