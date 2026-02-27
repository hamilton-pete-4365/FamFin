import SwiftUI
import SwiftData
import WidgetKit

@main
struct FamFinApp: App {
    let modelContainer: ModelContainer
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .auto

    init() {
        do {
            modelContainer = try SharedModelContainer.makeAppContainer()

            // Only seed default categories if onboarding has been completed.
            // During first launch, the onboarding flow handles category seeding
            // so the user can choose which category groups to include.
            let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            if hasCompletedOnboarding {
                DefaultCategories.seedIfNeeded(context: modelContainer.mainContext)
            }
            // Clean up duplicate BudgetAllocations from previous bugs
            FamFinApp.cleanupDuplicateAllocations(context: modelContainer.mainContext)
            // Generate any due recurring transactions
            RecurrenceEngine.processRecurringTransactions(context: modelContainer.mainContext)
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
                .tint(.accent)
                .preferredColorScheme(appearanceMode.colorScheme)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // Sync currency preference and refresh widgets
                        CurrencySettings.syncToSharedDefaults()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
