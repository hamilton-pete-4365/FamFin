import Foundation
import SwiftData
import Testing
@testable import FamFin

// MARK: - Category Activity Tests

@Suite("Category activity calculations")
struct CategoryActivityTests {

    @MainActor @Test("Expense in a month reduces category activity")
    func expenseReducesActivity() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let category = Category(name: "Groceries", emoji: "🛒")
        context.insert(category)

        let month = makeDate(year: 2025, month: 3)

        let tx = Transaction(amount: Decimal(80), payee: "Supermarket", date: month, type: .expense)
        tx.account = account
        tx.category = category
        context.insert(tx)
        try context.save()

        let activity = category.activity(in: month)
        #expect(activity == Decimal(-80))
    }

    @MainActor @Test("Income assigned to a category increases activity")
    func incomeIncreasesActivity() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let category = Category(name: "Refund", emoji: "💰")
        context.insert(category)

        let month = makeDate(year: 2025, month: 3)

        let tx = Transaction(amount: Decimal(50), payee: "Return", date: month, type: .income)
        tx.account = account
        tx.category = category
        context.insert(tx)
        try context.save()

        #expect(category.activity(in: month) == Decimal(50))
    }

    @MainActor @Test("Transactions in different months do not affect target month activity")
    func activityIsolatedByMonth() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let category = Category(name: "Groceries")
        context.insert(category)

        let march = makeDate(year: 2025, month: 3)
        let april = makeDate(year: 2025, month: 4)

        let marchTx = Transaction(amount: Decimal(100), payee: "A", date: march, type: .expense)
        marchTx.account = account
        marchTx.category = category
        context.insert(marchTx)

        let aprilTx = Transaction(amount: Decimal(200), payee: "B", date: april, type: .expense)
        aprilTx.account = account
        aprilTx.category = category
        context.insert(aprilTx)
        try context.save()

        #expect(category.activity(in: march) == Decimal(-100))
        #expect(category.activity(in: april) == Decimal(-200))
    }

    @MainActor @Test("Cross-boundary transfer Budget -> Tracking reduces activity")
    func crossBoundaryOutflowReducesActivity() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let budget = Account(name: "Current", type: .current, isBudget: true)
        let tracking = Account(name: "Loan", type: .loan, isBudget: false)
        context.insert(budget)
        context.insert(tracking)

        let category = Category(name: "Debt Payment")
        context.insert(category)

        let month = makeDate(year: 2025, month: 3)

        let transfer = Transaction(amount: Decimal(500), payee: "Loan", date: month, type: .transfer)
        transfer.account = budget
        transfer.transferToAccount = tracking
        transfer.category = category
        context.insert(transfer)
        try context.save()

        // Budget -> Tracking = outflow, reduces activity
        #expect(category.activity(in: month) == Decimal(-500))
    }

    @MainActor @Test("Cross-boundary transfer Tracking -> Budget increases activity")
    func crossBoundaryInflowIncreasesActivity() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let tracking = Account(name: "Investment", type: .asset, isBudget: false)
        let budget = Account(name: "Current", type: .current, isBudget: true)
        context.insert(tracking)
        context.insert(budget)

        let category = Category(name: "Income from Investments")
        context.insert(category)

        let month = makeDate(year: 2025, month: 3)

        let transfer = Transaction(amount: Decimal(200), payee: "Dividend", date: month, type: .transfer)
        transfer.account = tracking
        transfer.transferToAccount = budget
        transfer.category = category
        context.insert(transfer)
        try context.save()

        // Tracking -> Budget = inflow, increases activity
        #expect(category.activity(in: month) == Decimal(200))
    }

    @MainActor @Test("Tracking-only transactions are ignored in activity")
    func trackingOnlyTransactionsIgnored() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let tracking = Account(name: "Loan", type: .loan, isBudget: false)
        context.insert(tracking)

        let category = Category(name: "Interest")
        context.insert(category)

        let month = makeDate(year: 2025, month: 3)

        let tx = Transaction(amount: Decimal(50), payee: "Bank", date: month, type: .expense)
        tx.account = tracking
        tx.category = category
        context.insert(tx)
        try context.save()

        // Expense on a tracking account should be ignored
        #expect(category.activity(in: month) == Decimal.zero)
    }

    @MainActor @Test("No transactions yields zero activity")
    func noTransactionsZeroActivity() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let category = Category(name: "Empty")
        context.insert(category)
        try context.save()

        let month = makeDate(year: 2025, month: 3)
        #expect(category.activity(in: month) == Decimal.zero)
    }
}

// MARK: - Category Available Balance Tests

@Suite("Category available balance calculations")
struct CategoryAvailableTests {

    @MainActor @Test("Available = budgeted + activity (cumulative)")
    func availableIsBudgetedPlusActivity() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let category = Category(name: "Groceries")
        context.insert(category)

        let march = makeDate(year: 2025, month: 3)

        // Budget 300 for March
        let bm = BudgetMonth(month: march)
        context.insert(bm)
        let alloc = BudgetAllocation(budgeted: Decimal(300))
        alloc.category = category
        alloc.budgetMonth = bm
        context.insert(alloc)

        // Spend 80 in March
        let tx = Transaction(amount: Decimal(80), payee: "Shop", date: march, type: .expense)
        tx.account = account
        tx.category = category
        context.insert(tx)
        try context.save()

        // Available = 300 + (-80) = 220
        #expect(category.available(through: march) == Decimal(220))
    }

    @MainActor @Test("Available carries forward from previous months")
    func availableCarriesForward() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let category = Category(name: "Groceries")
        context.insert(category)

        let march = makeDate(year: 2025, month: 3)
        let april = makeDate(year: 2025, month: 4)

        // Budget 300 in March, spend 200
        let bmMarch = BudgetMonth(month: march)
        context.insert(bmMarch)
        let allocMarch = BudgetAllocation(budgeted: Decimal(300))
        allocMarch.category = category
        allocMarch.budgetMonth = bmMarch
        context.insert(allocMarch)

        let marchTx = Transaction(amount: Decimal(200), payee: "Shop", date: march, type: .expense)
        marchTx.account = account
        marchTx.category = category
        context.insert(marchTx)

        // Budget 300 in April, spend 250
        let bmApril = BudgetMonth(month: april)
        context.insert(bmApril)
        let allocApril = BudgetAllocation(budgeted: Decimal(300))
        allocApril.category = category
        allocApril.budgetMonth = bmApril
        context.insert(allocApril)

        let aprilTx = Transaction(amount: Decimal(250), payee: "Shop", date: april, type: .expense)
        aprilTx.account = account
        aprilTx.category = category
        context.insert(aprilTx)
        try context.save()

        // Through March: 300 - 200 = 100
        #expect(category.available(through: march) == Decimal(100))
        // Through April: (300 + 300) + (-200 + -250) = 600 - 450 = 150
        #expect(category.available(through: april) == Decimal(150))
    }

    @MainActor @Test("Overspent category shows negative available")
    func overspentCategory() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let category = Category(name: "Groceries")
        context.insert(category)

        let march = makeDate(year: 2025, month: 3)

        // Budget only 100
        let bm = BudgetMonth(month: march)
        context.insert(bm)
        let alloc = BudgetAllocation(budgeted: Decimal(100))
        alloc.category = category
        alloc.budgetMonth = bm
        context.insert(alloc)

        // Spend 200
        let tx = Transaction(amount: Decimal(200), payee: "Shop", date: march, type: .expense)
        tx.account = account
        tx.category = category
        context.insert(tx)
        try context.save()

        // Available = 100 - 200 = -100
        #expect(category.available(through: march) == Decimal(-100))
    }

    @MainActor @Test("No allocations and no transactions yields zero available")
    func noDataZeroAvailable() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let category = Category(name: "Empty")
        context.insert(category)
        try context.save()

        let month = makeDate(year: 2025, month: 3)
        #expect(category.available(through: month) == Decimal.zero)
    }
}

// MARK: - Category Budgeted Tests

@Suite("Category budgeted calculations")
struct CategoryBudgetedTests {

    @MainActor @Test("budgeted(in:) returns the amount for a specific month")
    func budgetedInMonth() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let category = Category(name: "Groceries")
        context.insert(category)

        let march = makeDate(year: 2025, month: 3)
        let april = makeDate(year: 2025, month: 4)

        let bmMarch = BudgetMonth(month: march)
        context.insert(bmMarch)
        let allocMarch = BudgetAllocation(budgeted: Decimal(300))
        allocMarch.category = category
        allocMarch.budgetMonth = bmMarch
        context.insert(allocMarch)

        let bmApril = BudgetMonth(month: april)
        context.insert(bmApril)
        let allocApril = BudgetAllocation(budgeted: Decimal(350))
        allocApril.category = category
        allocApril.budgetMonth = bmApril
        context.insert(allocApril)

        try context.save()

        #expect(category.budgeted(in: march) == Decimal(300))
        #expect(category.budgeted(in: april) == Decimal(350))
    }

    @MainActor @Test("cumulativeBudgeted sums across months")
    func cumulativeBudgetedSums() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let category = Category(name: "Groceries")
        context.insert(category)

        let march = makeDate(year: 2025, month: 3)
        let april = makeDate(year: 2025, month: 4)

        let bmMarch = BudgetMonth(month: march)
        context.insert(bmMarch)
        let allocMarch = BudgetAllocation(budgeted: Decimal(300))
        allocMarch.category = category
        allocMarch.budgetMonth = bmMarch
        context.insert(allocMarch)

        let bmApril = BudgetMonth(month: april)
        context.insert(bmApril)
        let allocApril = BudgetAllocation(budgeted: Decimal(350))
        allocApril.category = category
        allocApril.budgetMonth = bmApril
        context.insert(allocApril)

        try context.save()

        // Through March: only March (300)
        #expect(category.cumulativeBudgeted(through: march) == Decimal(300))
        // Through April: March + April (300 + 350 = 650)
        #expect(category.cumulativeBudgeted(through: april) == Decimal(650))
    }

    @MainActor @Test("budgeted returns zero for a month with no allocation")
    func noBudgetReturnsZero() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let category = Category(name: "Empty")
        context.insert(category)
        try context.save()

        let month = makeDate(year: 2025, month: 6)
        #expect(category.budgeted(in: month) == Decimal.zero)
    }
}

// MARK: - Category Hierarchy Tests

@Suite("Category hierarchy")
struct CategoryHierarchyTests {

    @MainActor @Test("Header has sorted children")
    func headerSortedChildren() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let header = Category(name: "Monthly", emoji: "📅", isHeader: true)
        context.insert(header)

        let groceries = Category(name: "Groceries", emoji: "🛒", sortOrder: 0)
        groceries.parent = header
        context.insert(groceries)

        let utilities = Category(name: "Utilities", emoji: "💡", sortOrder: 1)
        utilities.parent = header
        context.insert(utilities)

        let travel = Category(name: "Travel", emoji: "🚗", sortOrder: 2)
        travel.parent = header
        context.insert(travel)
        try context.save()

        let sorted = header.sortedChildren
        #expect(sorted.count == 3)
        #expect(sorted[0].name == "Groceries")
        #expect(sorted[1].name == "Utilities")
        #expect(sorted[2].name == "Travel")
    }

    @MainActor @Test("System category flag is preserved")
    func systemCategoryFlag() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let toBudget = Category(name: "To Budget", emoji: "💰", isSystem: true)
        context.insert(toBudget)
        try context.save()

        #expect(toBudget.isSystem == true)
        #expect(toBudget.isHeader == false)
    }
}

// MARK: - Category endOfMonth Helper Tests

@Suite("Category.endOfMonth helper")
struct CategoryEndOfMonthTests {

    @Test("endOfMonth returns the first of the next month")
    func endOfMonthReturnsNextMonthStart() {
        let march = makeDate(year: 2025, month: 3)
        let result = Category.endOfMonth(march)
        let expected = makeDate(year: 2025, month: 4)

        let calendar = Calendar.current
        let resultComps = calendar.dateComponents([.year, .month], from: result)
        let expectedComps = calendar.dateComponents([.year, .month], from: expected)

        #expect(resultComps.year == expectedComps.year)
        #expect(resultComps.month == expectedComps.month)
    }

    @Test("endOfMonth handles December to January rollover")
    func decemberRollover() {
        let december = makeDate(year: 2025, month: 12)
        let result = Category.endOfMonth(december)

        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: result)
        #expect(comps.year == 2026)
        #expect(comps.month == 1)
    }
}

// MARK: - Category Hidden Behaviour Tests

@Suite("Category hidden behaviour")
struct CategoryHiddenTests {

    @MainActor @Test("New categories default to not hidden")
    func defaultNotHidden() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let category = Category(name: "Test")
        context.insert(category)
        try context.save()

        #expect(category.isHidden == false)
    }

    @MainActor @Test("visibleSortedChildren excludes hidden children")
    func visibleExcludesHidden() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let header = Category(name: "Monthly", emoji: "📅", isHeader: true)
        context.insert(header)

        let groceries = Category(name: "Groceries", emoji: "🛒", sortOrder: 0)
        groceries.parent = header
        context.insert(groceries)

        let utilities = Category(name: "Utilities", emoji: "💡", sortOrder: 1)
        utilities.parent = header
        utilities.isHidden = true
        context.insert(utilities)

        let travel = Category(name: "Travel", emoji: "🚗", sortOrder: 2)
        travel.parent = header
        context.insert(travel)
        try context.save()

        let visible = header.visibleSortedChildren
        #expect(visible.count == 2)
        #expect(visible[0].name == "Groceries")
        #expect(visible[1].name == "Travel")
    }

    @MainActor @Test("sortedChildren still includes hidden children")
    func sortedIncludesHidden() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let header = Category(name: "Monthly", emoji: "📅", isHeader: true)
        context.insert(header)

        let groceries = Category(name: "Groceries", emoji: "🛒", sortOrder: 0)
        groceries.parent = header
        context.insert(groceries)

        let utilities = Category(name: "Utilities", emoji: "💡", sortOrder: 1)
        utilities.parent = header
        utilities.isHidden = true
        context.insert(utilities)
        try context.save()

        let sorted = header.sortedChildren
        #expect(sorted.count == 2)
        #expect(sorted[0].name == "Groceries")
        #expect(sorted[1].name == "Utilities")
    }

    @MainActor @Test("Hidden category retains transactions and allocations")
    func hiddenRetainsData() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let category = Category(name: "Groceries")
        context.insert(category)

        let month = makeDate(year: 2025, month: 3)

        let tx = Transaction(amount: Decimal(50), payee: "Shop", date: month, type: .expense)
        tx.account = account
        tx.category = category
        context.insert(tx)

        let bm = BudgetMonth(month: month)
        context.insert(bm)
        let alloc = BudgetAllocation(budgeted: Decimal(100))
        alloc.category = category
        alloc.budgetMonth = bm
        context.insert(alloc)
        try context.save()

        // Hide the category
        category.isHidden = true
        try context.save()

        // Data is still there
        #expect(category.transactions.count == 1)
        #expect(category.allocations.count == 1)
        #expect(category.activity(in: month) == Decimal(-50))
        #expect(category.budgeted(in: month) == Decimal(100))
    }
}

// MARK: - Category Transaction Count Tests

@Suite("Category transaction count")
struct CategoryTransactionCountTests {

    @MainActor @Test("transactionCount returns correct count for subcategory")
    func subcategoryTransactionCount() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let category = Category(name: "Groceries")
        context.insert(category)

        let month = makeDate(year: 2025, month: 3)

        for i in 1...5 {
            let tx = Transaction(amount: Decimal(i * 10), payee: "Shop \(i)", date: month, type: .expense)
            tx.account = account
            tx.category = category
            context.insert(tx)
        }
        try context.save()

        #expect(category.transactionCount == 5)
    }

    @MainActor @Test("transactionCount returns sum for header")
    func headerTransactionCount() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let header = Category(name: "Monthly", emoji: "📅", isHeader: true)
        context.insert(header)

        let groceries = Category(name: "Groceries", emoji: "🛒", sortOrder: 0)
        groceries.parent = header
        context.insert(groceries)

        let utilities = Category(name: "Utilities", emoji: "💡", sortOrder: 1)
        utilities.parent = header
        context.insert(utilities)

        let month = makeDate(year: 2025, month: 3)

        for i in 1...3 {
            let tx = Transaction(amount: Decimal(i * 10), payee: "Shop \(i)", date: month, type: .expense)
            tx.account = account
            tx.category = groceries
            context.insert(tx)
        }
        for i in 1...2 {
            let tx = Transaction(amount: Decimal(i * 20), payee: "Utility \(i)", date: month, type: .expense)
            tx.account = account
            tx.category = utilities
            context.insert(tx)
        }
        try context.save()

        #expect(header.transactionCount == 5)
        #expect(groceries.transactionCount == 3)
        #expect(utilities.transactionCount == 2)
    }

    @MainActor @Test("transactionCount returns zero for empty category")
    func emptyTransactionCount() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let category = Category(name: "Empty")
        context.insert(category)
        try context.save()

        #expect(category.transactionCount == 0)
    }
}

// MARK: - Category Move Between Groups Tests

@Suite("Category move between groups")
struct CategoryMoveTests {

    @MainActor @Test("Moving subcategory changes parent")
    func moveChangesParent() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let monthly = Category(name: "Monthly", emoji: "📅", isHeader: true, sortOrder: 0)
        context.insert(monthly)

        let fun = Category(name: "Fun", emoji: "🎉", isHeader: true, sortOrder: 1)
        context.insert(fun)

        let groceries = Category(name: "Groceries", emoji: "🛒", sortOrder: 0)
        groceries.parent = monthly
        context.insert(groceries)
        try context.save()

        #expect(groceries.parent?.name == "Monthly")

        // Move groceries to Fun
        groceries.parent = fun
        groceries.sortOrder = fun.children.count
        try context.save()

        #expect(groceries.parent?.name == "Fun")
    }

    @MainActor @Test("Moving subcategory reindexes old parent children")
    func moveReindexesOldParent() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let monthly = Category(name: "Monthly", emoji: "📅", isHeader: true, sortOrder: 0)
        context.insert(monthly)

        let fun = Category(name: "Fun", emoji: "🎉", isHeader: true, sortOrder: 1)
        context.insert(fun)

        let groceries = Category(name: "Groceries", emoji: "🛒", sortOrder: 0)
        groceries.parent = monthly
        context.insert(groceries)

        let utilities = Category(name: "Utilities", emoji: "💡", sortOrder: 1)
        utilities.parent = monthly
        context.insert(utilities)

        let travel = Category(name: "Travel", emoji: "🚗", sortOrder: 2)
        travel.parent = monthly
        context.insert(travel)
        try context.save()

        // Move utilities to Fun
        utilities.parent = fun
        utilities.sortOrder = fun.children.count

        // Reindex remaining Monthly children
        let remaining = monthly.sortedChildren.filter {
            $0.persistentModelID != utilities.persistentModelID
        }
        for (i, child) in remaining.enumerated() {
            child.sortOrder = i
        }
        try context.save()

        let monthlySorted = monthly.sortedChildren
        #expect(monthlySorted.count == 2)
        #expect(monthlySorted[0].name == "Groceries")
        #expect(monthlySorted[0].sortOrder == 0)
        #expect(monthlySorted[1].name == "Travel")
        #expect(monthlySorted[1].sortOrder == 1)
    }

    @MainActor @Test("Moved subcategory appends at end of new group")
    func moveAppendsAtEnd() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let monthly = Category(name: "Monthly", emoji: "📅", isHeader: true, sortOrder: 0)
        context.insert(monthly)

        let fun = Category(name: "Fun", emoji: "🎉", isHeader: true, sortOrder: 1)
        context.insert(fun)

        let holiday = Category(name: "Holiday", emoji: "✈️", sortOrder: 0)
        holiday.parent = fun
        context.insert(holiday)

        let groceries = Category(name: "Groceries", emoji: "🛒", sortOrder: 0)
        groceries.parent = monthly
        context.insert(groceries)
        try context.save()

        // Move groceries to Fun
        groceries.parent = fun
        groceries.sortOrder = fun.children.count
        try context.save()

        let funSorted = fun.sortedChildren
        #expect(funSorted.count == 2)
        #expect(funSorted[0].name == "Holiday")
        #expect(funSorted[1].name == "Groceries")
    }
}
