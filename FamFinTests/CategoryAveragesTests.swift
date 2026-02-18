import Foundation
import SwiftData
import Testing
@testable import FamFin

// MARK: - Category Average Monthly Spending Tests

@Suite("Category average monthly spending")
struct CategoryAverageSpendingTests {

    @MainActor @Test("Returns zero with no transaction history")
    func zeroWithNoHistory() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let category = BudgetCategory(name: "Groceries")
        context.insert(category)
        try context.save()

        let month = makeDate(year: 2025, month: 6)
        #expect(category.averageMonthlySpending(before: month) == Decimal.zero)
    }

    @MainActor @Test("Calculates average across months with spending")
    func averageAcrossMonths() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let category = BudgetCategory(name: "Groceries")
        context.insert(category)

        // Spend 100 in March, 200 in April
        let march = makeDate(year: 2025, month: 3)
        let april = makeDate(year: 2025, month: 4)

        let tx1 = Transaction(amount: Decimal(100), payee: "Shop A", date: march, type: .expense)
        tx1.account = account
        tx1.category = category
        context.insert(tx1)

        let tx2 = Transaction(amount: Decimal(200), payee: "Shop B", date: april, type: .expense)
        tx2.account = account
        tx2.category = category
        context.insert(tx2)
        try context.save()

        // Average before May should be (100 + 200) / 2 = 150
        let may = makeDate(year: 2025, month: 5)
        #expect(category.averageMonthlySpending(before: may, months: 3) == Decimal(150))
    }

    @MainActor @Test("Excludes months with no spending (income-only months)")
    func excludesIncomeOnlyMonths() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let category = BudgetCategory(name: "Refunds")
        context.insert(category)

        // March: income (net positive), April: expense (net negative)
        let march = makeDate(year: 2025, month: 3)
        let april = makeDate(year: 2025, month: 4)

        let income = Transaction(amount: Decimal(50), payee: "Refund", date: march, type: .income)
        income.account = account
        income.category = category
        context.insert(income)

        let expense = Transaction(amount: Decimal(80), payee: "Purchase", date: april, type: .expense)
        expense.account = account
        expense.category = category
        context.insert(expense)
        try context.save()

        // Only April should count (net -80, absolute = 80)
        let may = makeDate(year: 2025, month: 5)
        #expect(category.averageMonthlySpending(before: may, months: 3) == Decimal(80))
    }

    @MainActor @Test("Ignores tracking account transactions")
    func ignoresTrackingAccounts() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let tracking = Account(name: "Loan", type: .loan, isBudget: false)
        context.insert(tracking)

        let category = BudgetCategory(name: "Interest")
        context.insert(category)

        let march = makeDate(year: 2025, month: 3)
        let tx = Transaction(amount: Decimal(50), payee: "Bank", date: march, type: .expense)
        tx.account = tracking
        tx.category = category
        context.insert(tx)
        try context.save()

        let april = makeDate(year: 2025, month: 4)
        #expect(category.averageMonthlySpending(before: april) == Decimal.zero)
    }
}

// MARK: - Category Average Monthly Budgeted Tests

@Suite("Category average monthly budgeted")
struct CategoryAverageBudgetedTests {

    @MainActor @Test("Returns zero with no budget history")
    func zeroWithNoHistory() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let category = BudgetCategory(name: "Groceries")
        context.insert(category)
        try context.save()

        let month = makeDate(year: 2025, month: 6)
        #expect(category.averageMonthlyBudgeted(before: month) == Decimal.zero)
    }

    @MainActor @Test("Calculates average across months with budgets")
    func averageAcrossMonths() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let category = BudgetCategory(name: "Groceries")
        context.insert(category)

        // Budget 300 in March, 400 in April
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
        let allocApril = BudgetAllocation(budgeted: Decimal(400))
        allocApril.category = category
        allocApril.budgetMonth = bmApril
        context.insert(allocApril)
        try context.save()

        // Average before May should be (300 + 400) / 2 = 350
        let may = makeDate(year: 2025, month: 5)
        #expect(category.averageMonthlyBudgeted(before: may, months: 3) == Decimal(350))
    }

    @MainActor @Test("Excludes months with zero budget")
    func excludesZeroBudgetMonths() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let category = BudgetCategory(name: "Groceries")
        context.insert(category)

        // Only budget in March (not April)
        let march = makeDate(year: 2025, month: 3)

        let bm = BudgetMonth(month: march)
        context.insert(bm)
        let alloc = BudgetAllocation(budgeted: Decimal(300))
        alloc.category = category
        alloc.budgetMonth = bm
        context.insert(alloc)
        try context.save()

        // Average before May, looking back 3 months: only March has data
        let may = makeDate(year: 2025, month: 5)
        #expect(category.averageMonthlyBudgeted(before: may, months: 3) == Decimal(300))
    }
}
