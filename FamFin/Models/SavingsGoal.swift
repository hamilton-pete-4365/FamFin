import Foundation
import SwiftData

@Model
final class SavingsGoal {
    var name: String = ""
    var targetAmount: Decimal = 0
    var targetDate: Date?
    var emoji: String = "🎯"
    var createdAt: Date = Date()

    /// Link to a budget category — progress is derived from this category's available balance
    var linkedCategory: Category?

    // MARK: - Category-Derived Progress

    /// Current saved amount, derived from the linked category's cumulative available balance.
    /// Pass the current month (first of month) to calculate through that month.
    func currentAmount(through month: Date) -> Decimal {
        guard let category = linkedCategory else { return Decimal.zero }
        let available = category.available(through: month)
        return max(available, Decimal.zero)
    }

    /// Progress toward the goal as a value from 0.0 to 1.0
    func progress(through month: Date) -> Double {
        guard targetAmount > 0 else { return 0 }
        let ratio = NSDecimalNumber(decimal: currentAmount(through: month) / targetAmount).doubleValue
        return max(0, min(ratio, 1))
    }

    /// Whether the goal has been fully funded
    func isComplete(through month: Date) -> Bool {
        targetAmount > 0 && currentAmount(through: month) >= targetAmount
    }

    /// How much remains to reach the target
    func remainingAmount(through month: Date) -> Decimal {
        let remaining = targetAmount - currentAmount(through: month)
        return max(remaining, Decimal.zero)
    }

    /// How much needs to be budgeted per remaining month to reach the goal by the target date.
    /// Returns nil if no target date is set.
    func monthlyTarget(through month: Date) -> Decimal? {
        guard let targetDate else { return nil }
        guard targetAmount > 0 else { return Decimal.zero }
        let remaining = remainingAmount(through: month)
        guard remaining > 0 else { return Decimal.zero }

        let calendar = Calendar.current
        let months = calendar.dateComponents([.month], from: month, to: targetDate).month ?? 0
        guard months > 0 else { return remaining }

        return remaining / Decimal(months)
    }

    /// Number of calendar days remaining until the target date, or nil if no target date is set
    var daysRemaining: Int? {
        guard let targetDate else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: targetDate)).day
    }

    /// Projected completion date based on the category's average monthly budgeting rate.
    /// Returns nil if no linked category, no budgeting history, or if the goal is already complete.
    func projectedCompletionDate(through month: Date) -> Date? {
        guard let category = linkedCategory else { return nil }
        guard !isComplete(through: month) else { return nil }
        let remaining = remainingAmount(through: month)
        guard remaining > 0 else { return nil }

        let avgBudgeted = category.averageMonthlyBudgeted(before: month, months: 12)
        guard avgBudgeted > 0 else { return nil }

        let monthsNeeded = NSDecimalNumber(decimal: remaining / avgBudgeted).doubleValue
        let wholeMonths = Int(monthsNeeded.rounded(.up))
        return Calendar.current.date(byAdding: .month, value: wholeMonths, to: month)
    }

    // MARK: - Init

    init(
        name: String,
        targetAmount: Decimal,
        targetDate: Date? = nil,
        emoji: String = "🎯"
    ) {
        self.name = name
        self.targetAmount = targetAmount
        self.targetDate = targetDate
        self.emoji = emoji
        self.createdAt = Date()
    }
}
