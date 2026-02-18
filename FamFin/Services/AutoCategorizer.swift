import Foundation
import SwiftData

/// Matches imported transactions against existing `Payee` records to suggest
/// categories based on previous usage patterns.
struct AutoCategorizer {

    /// Attempt to fill in `suggestedCategory` for each transaction by matching
    /// the payee name against known `Payee` records in the database.
    ///
    /// Uses `localizedStandardContains()` for locale-aware fuzzy matching.
    static func categorize(
        _ transactions: [ImportedTransaction],
        context: ModelContext
    ) -> [ImportedTransaction] {
        let payees = (try? context.fetch(FetchDescriptor<Payee>())) ?? []
        guard !payees.isEmpty else { return transactions }

        return transactions.map { transaction in
            var updated = transaction

            // Try exact match first (case-insensitive)
            if let exactMatch = payees.first(where: {
                $0.name.localizedCaseInsensitiveCompare(transaction.payee) == .orderedSame
            }) {
                updated.suggestedCategory = exactMatch.lastUsedCategory
                return updated
            }

            // Try fuzzy match: does the imported payee contain a known payee name,
            // or does a known payee name contain the imported payee?
            if let fuzzyMatch = payees.first(where: { payee in
                transaction.payee.localizedStandardContains(payee.name) ||
                payee.name.localizedStandardContains(transaction.payee)
            }) {
                updated.suggestedCategory = fuzzyMatch.lastUsedCategory
                return updated
            }

            return updated
        }
    }

    /// Check each imported transaction against existing transactions in the database
    /// to flag potential duplicates. A duplicate is detected when an existing transaction
    /// matches on date (same calendar day), amount, and payee.
    static func detectDuplicates(
        _ transactions: [ImportedTransaction],
        context: ModelContext
    ) -> [ImportedTransaction] {
        let existingTransactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let calendar = Calendar.current

        return transactions.map { imported in
            var updated = imported
            let isDuplicate = existingTransactions.contains { existing in
                // Same calendar day
                guard calendar.isDate(existing.date, inSameDayAs: imported.date) else { return false }
                // Same amount
                guard existing.amount == imported.amount else { return false }
                // Same payee (case-insensitive)
                return existing.payee.localizedCaseInsensitiveCompare(imported.payee) == .orderedSame
            }
            updated.isPotentialDuplicate = isDuplicate
            return updated
        }
    }
}
