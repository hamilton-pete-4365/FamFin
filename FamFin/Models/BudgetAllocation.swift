import Foundation
import SwiftData

/// Represents how much money is assigned to a category for a specific month
/// This is the "envelope" in envelope budgeting
@Model
final class BudgetAllocation {
    var budgeted: Decimal
    var category: Category?
    var budgetMonth: BudgetMonth?

    /// Net activity in this category this month (expenses negative, income positive)
    var activityThisMonth: Decimal {
        guard let category = category, let budgetMonth = budgetMonth else {
            return Decimal.zero
        }
        return category.activity(in: budgetMonth.month)
    }

    /// Cumulative available balance through this allocation's month (envelope carry-forward)
    var available: Decimal {
        guard let category = category, let budgetMonth = budgetMonth else {
            return Decimal.zero
        }
        return category.available(through: budgetMonth.month)
    }

    init(budgeted: Decimal = Decimal.zero) {
        self.budgeted = budgeted
    }
}
