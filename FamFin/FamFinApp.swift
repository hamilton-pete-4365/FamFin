import SwiftUI
import SwiftData

@main
struct FamFinApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for:
                Account.self,
                Transaction.self,
                Category.self,
                BudgetMonth.self,
                BudgetAllocation.self,
                SavingsGoal.self,
                Payee.self
            )
            // Seed default categories on first launch
            DefaultCategories.seedIfNeeded(context: modelContainer.mainContext)
            // Clean up duplicate BudgetAllocations from previous bugs
            FamFinApp.cleanupDuplicateAllocations(context: modelContainer.mainContext)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    /// Remove duplicate BudgetAllocations (same category + same month).
    /// Keeps the first allocation found and deletes the rest.
    /// Fixes data corruption from a previous bug where === identity checks
    /// failed to find existing allocations, creating duplicates.
    static func cleanupDuplicateAllocations(context: ModelContext) {
        guard let budgetMonths = try? context.fetch(FetchDescriptor<BudgetMonth>()) else { return }

        var deletedAny = false
        for bm in budgetMonths {
            var seen: [String: BudgetAllocation] = [:]  // key = category persistentModelID
            for alloc in bm.allocations {
                guard let cat = alloc.category else {
                    // Orphan allocation with no category — delete it
                    context.delete(alloc)
                    deletedAny = true
                    continue
                }
                let key = "\(cat.persistentModelID)"
                if let existing = seen[key] {
                    // Duplicate! Keep whichever has a non-zero budgeted amount (or the first)
                    if existing.budgeted == .zero && alloc.budgeted != .zero {
                        context.delete(existing)
                        seen[key] = alloc
                    } else {
                        context.delete(alloc)
                    }
                    deletedAny = true
                } else {
                    seen[key] = alloc
                }
            }
        }
        if deletedAny {
            try? context.save()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
