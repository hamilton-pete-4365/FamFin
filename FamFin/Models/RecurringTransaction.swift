import Foundation
import SwiftData

/// A template for automatically generating transactions on a recurring schedule.
/// Each active recurring transaction creates real Transaction records when its
/// nextOccurrence date arrives.
@Model
final class RecurringTransaction {
    // MARK: - Core transaction data

    var amount: Decimal = 0
    var payee: String = ""
    var memo: String = ""
    var type: TransactionType = TransactionType.expense

    // MARK: - Recurrence schedule

    var frequency: RecurrenceFrequency = RecurrenceFrequency.monthly
    var startDate: Date = Date()
    var endDate: Date?
    var nextOccurrence: Date = Date()
    var isActive: Bool = true

    // MARK: - Relationships (all optional for CloudKit compatibility)

    var account: Account?
    var category: Category?

    /// For transfer-type recurring transactions: the destination account.
    var transferToAccount: Account?

    // MARK: - Metadata

    var createdAt: Date = Date()

    init(
        amount: Decimal,
        payee: String,
        memo: String = "",
        type: TransactionType = .expense,
        frequency: RecurrenceFrequency = .monthly,
        startDate: Date = Date(),
        endDate: Date? = nil
    ) {
        self.amount = amount
        self.payee = payee
        self.memo = memo
        self.type = type
        self.frequency = frequency
        self.startDate = startDate
        self.endDate = endDate
        self.nextOccurrence = startDate
        self.isActive = true
        self.createdAt = Date()
    }
}

// MARK: - Recurrence Frequency

enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Biweekly"
    case monthly = "Monthly"
    case yearly = "Yearly"

    var id: String { rawValue }

    /// Human-readable label for display
    var displayName: String { rawValue }

    /// Advances the given date by one period of this frequency.
    func nextDate(after date: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}
