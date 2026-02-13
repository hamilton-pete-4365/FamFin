import Foundation
import SwiftData

@Model
final class BudgetMonth {
    var month: Date  // first day of the month
    var note: String

    @Relationship(deleteRule: .cascade)
    var allocations: [BudgetAllocation] = []

    /// Total amount budgeted (assigned to envelopes) this month
    var totalBudgeted: Decimal {
        allocations.reduce(Decimal.zero) { $0 + $1.budgeted }
    }

    init(month: Date, note: String = "") {
        // Normalize to first day of month
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: month)
        self.month = calendar.date(from: components) ?? month
        self.note = note
    }
}
