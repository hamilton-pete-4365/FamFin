import Foundation
import SwiftData

@Model
final class Transaction {
    var amount: Decimal = 0
    var payee: String = ""
    var memo: String = ""
    var date: Date = Date()
    var type: TransactionType = TransactionType.expense
    var isCleared: Bool = false

    var account: Account?
    var category: Category?

    /// For transfers: the destination account. The source is `account`.
    var transferToAccount: Account?

    init(
        amount: Decimal,
        payee: String,
        memo: String = "",
        date: Date = Date(),
        type: TransactionType = .expense,
        isCleared: Bool = false
    ) {
        self.amount = amount
        self.payee = payee
        self.memo = memo
        self.date = date
        self.type = type
        self.isCleared = isCleared
    }

    /// Signed amount for sorting: expenses negative, income positive, transfers zero.
    var signedAmount: Decimal {
        switch type {
        case .expense: return -amount
        case .income: return amount
        case .transfer: return 0
        }
    }

    /// Whether this transfer crosses the Budget/Tracking boundary (requires a category)
    var transferNeedsCategory: Bool {
        guard type == .transfer,
              let from = account,
              let to = transferToAccount else { return false }
        return from.isBudget != to.isBudget
    }
}

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case income = "Income"
    case expense = "Expense"
    case transfer = "Transfer"

    var id: String { rawValue }
}
