import Foundation

/// A lightweight value type representing a transaction parsed from an imported file (CSV or OFX).
/// This is NOT a SwiftData model -- it exists only in the import pipeline before the user
/// confirms which transactions to save.
struct ImportedTransaction: Identifiable {
    let id = UUID()

    /// The date the transaction occurred.
    var date: Date

    /// The absolute transaction amount. Sign convention: positive values are stored here
    /// and the `isExpense` flag determines direction.
    var amount: Decimal

    /// The payee or description from the bank statement.
    var payee: String

    /// Optional memo, reference, or additional description.
    var memo: String

    /// A unique reference from the bank (e.g. FITID in OFX) used for duplicate detection.
    var reference: String

    /// Whether this transaction represents money going out (expense) vs coming in (income).
    var isExpense: Bool

    /// A category suggested by the auto-categoriser, based on payee matching.
    var suggestedCategory: Category?

    /// Whether the user has selected this transaction for import. Defaults to `true`.
    var isSelected: Bool = true

    /// Whether this transaction appears to be a duplicate of an existing transaction.
    var isPotentialDuplicate: Bool = false
}
