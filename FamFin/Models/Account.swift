import Foundation
import SwiftData

@Model
final class Account {
    var name: String = ""
    var type: AccountType = AccountType.current
    var isBudget: Bool = true  // true = Budget account, false = Tracking account
    var sortOrder: Int = 0  // for manual reordering
    var createdAt: Date = Date()
    /// Date the account was last reconciled, or nil if never reconciled.
    var lastReconciledDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction] = []

    /// Transactions where money was transferred INTO this account
    @Relationship(deleteRule: .nullify, inverse: \Transaction.transferToAccount)
    var incomingTransfers: [Transaction] = []

    var balance: Decimal {
        var total = Decimal.zero
        for transaction in transactions {
            switch transaction.type {
            case .income:
                total += transaction.amount
            case .expense:
                total -= transaction.amount
            case .transfer:
                // Outgoing transfer: money leaves this account
                total -= transaction.amount
            }
        }
        // Add incoming transfers
        for transaction in incomingTransfers {
            total += transaction.amount
        }
        return total
    }

    init(name: String, type: AccountType, isBudget: Bool = true, sortOrder: Int = 0) {
        self.name = name
        self.type = type
        self.isBudget = isBudget
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case current = "Current"
    case savings = "Savings"
    case creditCard = "Credit Card"
    case loan = "Loan"
    case mortgage = "Mortgage"
    case asset = "Asset"
    case liability = "Liability"

    var id: String { rawValue }

    var defaultIsBudget: Bool {
        switch self {
        case .current, .savings, .creditCard:
            return true
        case .loan, .mortgage, .asset, .liability:
            return false
        }
    }

    // Support old values from earlier builds
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "Checking":
            self = .current
        case "Cash":
            self = .current
        default:
            self = AccountType(rawValue: rawValue) ?? .current
        }
    }
}
