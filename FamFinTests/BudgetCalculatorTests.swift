import Foundation
import SwiftData
import Testing
@testable import FamFin

// MARK: - BudgetCalculator "To Budget" Tests

@Suite("BudgetCalculator - To Budget")
struct BudgetCalculatorToBudgetTests {

    @MainActor @Test("To Budget = uncategorised income when no allocations exist")
    func toBudgetWithUnallocatedIncome() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let toBudget = Category(name: "To Budget", emoji: "💰", isSystem: true)
        context.insert(toBudget)

        let month = makeDate(year: 2025, month: 3)

        // Uncategorised income of 2000
        let income = Transaction(amount: Decimal(2000), payee: "Salary", date: month, type: .income)
        income.account = account
        // No category assigned
        context.insert(income)
        try context.save()

        let result = BudgetCalculator.toBudgetAvailable(
            through: month,
            toBudgetCategory: toBudget,
            accounts: [account],
            context: context
        )

        #expect(result == Decimal(2000))
    }

    @MainActor @Test("To Budget = income - allocations")
    func toBudgetIncomeMinusAllocations() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let toBudget = Category(name: "To Budget", emoji: "💰", isSystem: true)
        context.insert(toBudget)

        let groceries = Category(name: "Groceries")
        context.insert(groceries)

        let month = makeDate(year: 2025, month: 3)

        // Uncategorised income
        let income = Transaction(amount: Decimal(2000), payee: "Salary", date: month, type: .income)
        income.account = account
        context.insert(income)

        // Allocate 300 to Groceries
        let bm = BudgetMonth(month: month)
        context.insert(bm)
        let alloc = BudgetAllocation(budgeted: Decimal(300))
        alloc.category = groceries
        alloc.budgetMonth = bm
        context.insert(alloc)
        try context.save()

        let result = BudgetCalculator.toBudgetAvailable(
            through: month,
            toBudgetCategory: toBudget,
            accounts: [account],
            context: context
        )

        #expect(result == Decimal(1700))
    }

    @MainActor @Test("To Budget accounts for multiple allocations across categories")
    func toBudgetMultipleAllocations() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let toBudget = Category(name: "To Budget", emoji: "💰", isSystem: true)
        context.insert(toBudget)

        let groceries = Category(name: "Groceries")
        let utilities = Category(name: "Utilities")
        context.insert(groceries)
        context.insert(utilities)

        let month = makeDate(year: 2025, month: 3)

        let income = Transaction(amount: Decimal(3000), payee: "Salary", date: month, type: .income)
        income.account = account
        context.insert(income)

        let bm = BudgetMonth(month: month)
        context.insert(bm)

        let allocGroceries = BudgetAllocation(budgeted: Decimal(500))
        allocGroceries.category = groceries
        allocGroceries.budgetMonth = bm
        context.insert(allocGroceries)

        let allocUtilities = BudgetAllocation(budgeted: Decimal(200))
        allocUtilities.category = utilities
        allocUtilities.budgetMonth = bm
        context.insert(allocUtilities)

        try context.save()

        let result = BudgetCalculator.toBudgetAvailable(
            through: month,
            toBudgetCategory: toBudget,
            accounts: [account],
            context: context
        )

        // 3000 - 500 - 200 = 2300
        #expect(result == Decimal(2300))
    }

    @MainActor @Test("To Budget includes uncategorised tracking transfers into budget accounts")
    func toBudgetIncludesTrackingTransfersIn() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let budget = Account(name: "Current", type: .current, isBudget: true)
        let tracking = Account(name: "Investment", type: .asset, isBudget: false)
        context.insert(budget)
        context.insert(tracking)

        let toBudget = Category(name: "To Budget", emoji: "💰", isSystem: true)
        context.insert(toBudget)

        let month = makeDate(year: 2025, month: 3)

        // Income on budget account
        let income = Transaction(amount: Decimal(1000), payee: "Salary", date: month, type: .income)
        income.account = budget
        context.insert(income)

        // Uncategorised transfer from tracking to budget
        let transfer = Transaction(amount: Decimal(500), payee: "From investment", date: month, type: .transfer)
        transfer.account = tracking
        transfer.transferToAccount = budget
        // No category
        context.insert(transfer)
        try context.save()

        let result = BudgetCalculator.toBudgetAvailable(
            through: month,
            toBudgetCategory: toBudget,
            accounts: [budget, tracking],
            context: context
        )

        // 1000 (income) + 500 (tracking->budget transfer) = 1500
        #expect(result == Decimal(1500))
    }

    @MainActor @Test("To Budget subtracts uncategorised expenses on budget accounts")
    func toBudgetSubtractsUncategorisedExpenses() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let toBudget = Category(name: "To Budget", emoji: "💰", isSystem: true)
        context.insert(toBudget)

        let month = makeDate(year: 2025, month: 3)

        let income = Transaction(amount: Decimal(2000), payee: "Salary", date: month, type: .income)
        income.account = account
        context.insert(income)

        // Uncategorised expense
        let expense = Transaction(amount: Decimal(150), payee: "Unknown", date: month, type: .expense)
        expense.account = account
        context.insert(expense)
        try context.save()

        let result = BudgetCalculator.toBudgetAvailable(
            through: month,
            toBudgetCategory: toBudget,
            accounts: [account],
            context: context
        )

        // 2000 - 150 = 1850
        #expect(result == Decimal(1850))
    }

    @MainActor @Test("To Budget is zero when everything is fully allocated")
    func fullyAllocated() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let toBudget = Category(name: "To Budget", emoji: "💰", isSystem: true)
        context.insert(toBudget)

        let groceries = Category(name: "Groceries")
        context.insert(groceries)

        let month = makeDate(year: 2025, month: 3)

        let income = Transaction(amount: Decimal(1000), payee: "Salary", date: month, type: .income)
        income.account = account
        context.insert(income)

        let bm = BudgetMonth(month: month)
        context.insert(bm)
        let alloc = BudgetAllocation(budgeted: Decimal(1000))
        alloc.category = groceries
        alloc.budgetMonth = bm
        context.insert(alloc)
        try context.save()

        let result = BudgetCalculator.toBudgetAvailable(
            through: month,
            toBudgetCategory: toBudget,
            accounts: [account],
            context: context
        )

        #expect(result == Decimal.zero)
    }

    @MainActor @Test("To Budget goes negative when over-allocated")
    func overAllocated() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let toBudget = Category(name: "To Budget", emoji: "💰", isSystem: true)
        context.insert(toBudget)

        let groceries = Category(name: "Groceries")
        context.insert(groceries)

        let month = makeDate(year: 2025, month: 3)

        let income = Transaction(amount: Decimal(500), payee: "Salary", date: month, type: .income)
        income.account = account
        context.insert(income)

        let bm = BudgetMonth(month: month)
        context.insert(bm)
        let alloc = BudgetAllocation(budgeted: Decimal(800))
        alloc.category = groceries
        alloc.budgetMonth = bm
        context.insert(alloc)
        try context.save()

        let result = BudgetCalculator.toBudgetAvailable(
            through: month,
            toBudgetCategory: toBudget,
            accounts: [account],
            context: context
        )

        // 500 - 800 = -300
        #expect(result == Decimal(-300))
    }

    @MainActor @Test("To Budget with no transactions and no allocations is zero")
    func emptyBudget() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let toBudget = Category(name: "To Budget", emoji: "💰", isSystem: true)
        context.insert(toBudget)
        try context.save()

        let month = makeDate(year: 2025, month: 3)

        let result = BudgetCalculator.toBudgetAvailable(
            through: month,
            toBudgetCategory: toBudget,
            accounts: [],
            context: context
        )

        #expect(result == Decimal.zero)
    }
}

// MARK: - BudgetCalculator Cumulative & Future Budgeted Tests

@Suite("BudgetCalculator - cumulative and future budgeted")
struct BudgetCalculatorCumulativeTests {

    @MainActor @Test("cumulativeBudgeted sums all allocations through the month")
    func cumulativeBudgetedSums() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let groceries = Category(name: "Groceries")
        let utilities = Category(name: "Utilities")
        context.insert(groceries)
        context.insert(utilities)

        let march = makeDate(year: 2025, month: 3)
        let april = makeDate(year: 2025, month: 4)

        let bmMarch = BudgetMonth(month: march)
        context.insert(bmMarch)

        let allocGrocMarch = BudgetAllocation(budgeted: Decimal(300))
        allocGrocMarch.category = groceries
        allocGrocMarch.budgetMonth = bmMarch
        context.insert(allocGrocMarch)

        let allocUtilMarch = BudgetAllocation(budgeted: Decimal(100))
        allocUtilMarch.category = utilities
        allocUtilMarch.budgetMonth = bmMarch
        context.insert(allocUtilMarch)

        let bmApril = BudgetMonth(month: april)
        context.insert(bmApril)

        let allocGrocApril = BudgetAllocation(budgeted: Decimal(350))
        allocGrocApril.category = groceries
        allocGrocApril.budgetMonth = bmApril
        context.insert(allocGrocApril)
        try context.save()

        // Through March: 300 + 100 = 400
        #expect(BudgetCalculator.cumulativeBudgeted(through: march, context: context) == Decimal(400))
        // Through April: 300 + 100 + 350 = 750
        #expect(BudgetCalculator.cumulativeBudgeted(through: april, context: context) == Decimal(750))
    }

    @MainActor @Test("futureBudgeted sums allocations after the given month")
    func futureBudgetedSums() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let groceries = Category(name: "Groceries")
        context.insert(groceries)

        let march = makeDate(year: 2025, month: 3)
        let april = makeDate(year: 2025, month: 4)
        let may = makeDate(year: 2025, month: 5)

        let bmMarch = BudgetMonth(month: march)
        context.insert(bmMarch)
        let allocMarch = BudgetAllocation(budgeted: Decimal(300))
        allocMarch.category = groceries
        allocMarch.budgetMonth = bmMarch
        context.insert(allocMarch)

        let bmApril = BudgetMonth(month: april)
        context.insert(bmApril)
        let allocApril = BudgetAllocation(budgeted: Decimal(350))
        allocApril.category = groceries
        allocApril.budgetMonth = bmApril
        context.insert(allocApril)

        let bmMay = BudgetMonth(month: may)
        context.insert(bmMay)
        let allocMay = BudgetAllocation(budgeted: Decimal(400))
        allocMay.category = groceries
        allocMay.budgetMonth = bmMay
        context.insert(allocMay)
        try context.save()

        // Future after March = April (350) + May (400) = 750
        #expect(BudgetCalculator.futureBudgeted(after: march, context: context) == Decimal(750))
        // Future after April = May (400)
        #expect(BudgetCalculator.futureBudgeted(after: april, context: context) == Decimal(400))
        // Future after May = 0
        #expect(BudgetCalculator.futureBudgeted(after: may, context: context) == Decimal.zero)
    }
}
