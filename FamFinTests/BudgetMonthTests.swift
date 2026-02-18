import Foundation
import SwiftData
import Testing
@testable import FamFin

// MARK: - BudgetMonth Tests

@Suite("BudgetMonth model")
struct BudgetMonthTests {

    @MainActor @Test("BudgetMonth normalises to first day of month")
    func normalisesToFirstOfMonth() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        // Create a date in the middle of the month
        let midMonth = makeDate(year: 2025, month: 3, day: 15)
        let bm = BudgetMonth(month: midMonth)
        context.insert(bm)
        try context.save()

        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: bm.month)
        #expect(comps.year == 2025)
        #expect(comps.month == 3)
        #expect(comps.day == 1)
    }

    @MainActor @Test("totalBudgeted sums all allocations")
    func totalBudgetedSumsAllocations() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let groceries = Category(name: "Groceries")
        let utilities = Category(name: "Utilities")
        context.insert(groceries)
        context.insert(utilities)

        let month = makeDate(year: 2025, month: 3)
        let bm = BudgetMonth(month: month)
        context.insert(bm)

        let alloc1 = BudgetAllocation(budgeted: Decimal(300))
        alloc1.category = groceries
        alloc1.budgetMonth = bm
        context.insert(alloc1)

        let alloc2 = BudgetAllocation(budgeted: Decimal(150))
        alloc2.category = utilities
        alloc2.budgetMonth = bm
        context.insert(alloc2)
        try context.save()

        #expect(bm.totalBudgeted == Decimal(450))
    }

    @MainActor @Test("totalBudgeted is zero with no allocations")
    func totalBudgetedZeroEmpty() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let month = makeDate(year: 2025, month: 3)
        let bm = BudgetMonth(month: month)
        context.insert(bm)
        try context.save()

        #expect(bm.totalBudgeted == Decimal.zero)
    }

    @MainActor @Test("BudgetMonth preserves note")
    func preservesNote() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let month = makeDate(year: 2025, month: 3)
        let bm = BudgetMonth(month: month, note: "March budget")
        context.insert(bm)
        try context.save()

        #expect(bm.note == "March budget")
    }
}

// MARK: - BudgetAllocation Tests

@Suite("BudgetAllocation model")
struct BudgetAllocationTests {

    @MainActor @Test("Default budgeted is zero")
    func defaultBudgetedZero() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let alloc = BudgetAllocation()
        context.insert(alloc)
        try context.save()

        #expect(alloc.budgeted == Decimal.zero)
    }

    @MainActor @Test("activityThisMonth returns zero without linked category")
    func activityWithoutCategory() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let month = makeDate(year: 2025, month: 3)
        let bm = BudgetMonth(month: month)
        context.insert(bm)

        let alloc = BudgetAllocation(budgeted: Decimal(300))
        alloc.budgetMonth = bm
        // No category linked
        context.insert(alloc)
        try context.save()

        #expect(alloc.activityThisMonth == Decimal.zero)
    }

    @MainActor @Test("activityThisMonth delegates to category.activity")
    func activityDelegatesToCategory() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let category = Category(name: "Groceries")
        context.insert(category)

        let month = makeDate(year: 2025, month: 3)
        let bm = BudgetMonth(month: month)
        context.insert(bm)

        let alloc = BudgetAllocation(budgeted: Decimal(300))
        alloc.category = category
        alloc.budgetMonth = bm
        context.insert(alloc)

        let tx = Transaction(amount: Decimal(80), payee: "Shop", date: month, type: .expense)
        tx.account = account
        tx.category = category
        context.insert(tx)
        try context.save()

        #expect(alloc.activityThisMonth == Decimal(-80))
    }

    @MainActor @Test("available delegates to category.available")
    func availableDelegatesToCategory() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let category = Category(name: "Groceries")
        context.insert(category)

        let month = makeDate(year: 2025, month: 3)
        let bm = BudgetMonth(month: month)
        context.insert(bm)

        let alloc = BudgetAllocation(budgeted: Decimal(300))
        alloc.category = category
        alloc.budgetMonth = bm
        context.insert(alloc)

        let tx = Transaction(amount: Decimal(80), payee: "Shop", date: month, type: .expense)
        tx.account = account
        tx.category = category
        context.insert(tx)
        try context.save()

        // Available = 300 + (-80) = 220
        #expect(alloc.available == Decimal(220))
    }

    @MainActor @Test("available returns zero without linked category")
    func availableZeroWithoutCategory() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let month = makeDate(year: 2025, month: 3)
        let bm = BudgetMonth(month: month)
        context.insert(bm)

        let alloc = BudgetAllocation(budgeted: Decimal(300))
        alloc.budgetMonth = bm
        context.insert(alloc)
        try context.save()

        #expect(alloc.available == Decimal.zero)
    }
}
