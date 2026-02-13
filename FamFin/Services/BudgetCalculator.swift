import Foundation
import SwiftData

/// Centralises budget calculations that span multiple models.
///
/// "To Budget" is a real system category. Its balance is:
///   direct activity on To Budget category (transactions assigned to it)
///   + uncategorised income/expenses on Budget accounts (category = nil)
///   + incoming transfers from Tracking → Budget accounts
///   - total budgeted to all other categories (allocations = transfers out of To Budget)
///
/// Fundamental rule:
///   Budget Account Total = "To Budget" balance + Sum of all other category available balances
struct BudgetCalculator {

    /// Compute the "To Budget" available balance through a given month.
    ///
    /// Uses modelContext to directly query BudgetAllocations, avoiding stale
    /// relationship data from @Query caches.
    static func toBudgetAvailable(
        through month: Date,
        toBudgetCategory: Category,
        accounts: [Account],
        context: ModelContext
    ) -> Decimal {
        let endOfMonth = endOfMonth(month)

        // 1. Direct activity on the To Budget category itself
        let directActivity = toBudgetCategory.cumulativeActivity(through: month)

        // 2. Uncategorised income/expenses on Budget accounts (category = nil)
        var uncategorisedNet = Decimal.zero
        for account in accounts where account.isBudget {
            for transaction in account.transactions {
                guard transaction.date < endOfMonth else { continue }
                guard transaction.category == nil else { continue }
                switch transaction.type {
                case .income:
                    uncategorisedNet += transaction.amount
                case .expense:
                    uncategorisedNet -= transaction.amount
                case .transfer:
                    break
                }
            }
        }

        // 3. Incoming transfers from Tracking → Budget accounts
        var trackingTransfers = Decimal.zero
        for account in accounts where account.isBudget {
            for transaction in account.incomingTransfers {
                guard transaction.type == .transfer else { continue }
                guard transaction.date < endOfMonth else { continue }
                guard transaction.account?.isBudget == false else { continue }
                trackingTransfers += transaction.amount
            }
        }

        // 4. Total budgeted across all categories in all months up to and including this month.
        //    Query BudgetAllocations directly via modelContext for a fresh read.
        let totalBudgeted = cumulativeBudgeted(through: month, context: context)

        return directActivity + uncategorisedNet + trackingTransfers - totalBudgeted
    }

    /// Sum of all BudgetAllocation.budgeted amounts from all time through the given month.
    /// Queries the modelContext directly for fresh data.
    static func cumulativeBudgeted(through month: Date, context: ModelContext) -> Decimal {
        let endOfMonth = endOfMonth(month)
        let descriptor = FetchDescriptor<BudgetAllocation>()
        guard let allAllocations = try? context.fetch(descriptor) else { return Decimal.zero }

        return allAllocations
            .filter { alloc in
                guard let allocMonth = alloc.budgetMonth?.month else { return false }
                return allocMonth < endOfMonth
            }
            .reduce(Decimal.zero) { $0 + $1.budgeted }
    }

    // MARK: - Helpers

    private static func endOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let firstOfMonth = calendar.date(from: comps),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth) else {
            return date
        }
        return nextMonth
    }
}
