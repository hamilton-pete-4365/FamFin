import Foundation
import SwiftData

@Model
final class SavingsGoal {
    var name: String
    var targetAmount: Decimal
    var savedAmount: Decimal
    var targetDate: Date?
    var emoji: String
    var createdAt: Date

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return NSDecimalNumber(decimal: savedAmount / targetAmount).doubleValue
    }

    var isComplete: Bool {
        savedAmount >= targetAmount
    }

    /// How much you need to save per month to reach your goal
    var monthlyTarget: Decimal? {
        guard let targetDate = targetDate else { return nil }
        let remaining = targetAmount - savedAmount
        guard remaining > 0 else { return Decimal.zero }

        let calendar = Calendar.current
        let months = calendar.dateComponents([.month], from: Date(), to: targetDate).month ?? 0
        guard months > 0 else { return remaining }

        return remaining / Decimal(months)
    }

    init(
        name: String,
        targetAmount: Decimal,
        savedAmount: Decimal = Decimal.zero,
        targetDate: Date? = nil,
        emoji: String = "🎯"
    ) {
        self.name = name
        self.targetAmount = targetAmount
        self.savedAmount = savedAmount
        self.targetDate = targetDate
        self.emoji = emoji
        self.createdAt = Date()
    }
}
