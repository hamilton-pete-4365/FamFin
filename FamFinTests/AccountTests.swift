import Foundation
import SwiftData
import Testing
@testable import FamFin

// MARK: - Account Balance Tests

@Suite("Account balance calculations")
struct AccountBalanceTests {

    @MainActor @Test("Empty account has zero balance")
    func emptyAccountBalance() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current)
        context.insert(account)
        try context.save()

        #expect(account.balance == Decimal.zero)
    }

    @MainActor @Test("Income transaction increases account balance")
    func incomeIncreasesBalance() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current)
        context.insert(account)

        let tx = Transaction(amount: Decimal(150), payee: "Employer", type: .income)
        tx.account = account
        context.insert(tx)
        try context.save()

        #expect(account.balance == Decimal(150))
    }

    @MainActor @Test("Expense transaction decreases account balance")
    func expenseDecreasesBalance() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current)
        context.insert(account)

        let income = Transaction(amount: Decimal(500), payee: "Employer", type: .income)
        income.account = account
        context.insert(income)

        let expense = Transaction(amount: Decimal(100), payee: "Shop", type: .expense)
        expense.account = account
        context.insert(expense)
        try context.save()

        #expect(account.balance == Decimal(400))
    }

    @MainActor @Test("Transfer between two budget accounts moves money correctly")
    func transferBetweenBudgetAccounts() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let checking = Account(name: "Checking", type: .current, isBudget: true)
        let savings = Account(name: "Savings", type: .savings, isBudget: true)
        context.insert(checking)
        context.insert(savings)

        // Seed checking with income
        let income = Transaction(amount: Decimal(1000), payee: "Employer", type: .income)
        income.account = checking
        context.insert(income)

        // Transfer 300 from checking to savings
        let transfer = Transaction(amount: Decimal(300), payee: "Transfer", type: .transfer)
        transfer.account = checking
        transfer.transferToAccount = savings
        context.insert(transfer)
        try context.save()

        // Checking: 1000 (income) - 300 (outgoing transfer) = 700
        #expect(checking.balance == Decimal(700))
        // Savings: 0 + 300 (incoming transfer) = 300
        #expect(savings.balance == Decimal(300))
    }

    @MainActor @Test("Transfer from budget to tracking account (cross-boundary)")
    func crossBoundaryTransfer() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let budgetAccount = Account(name: "Current", type: .current, isBudget: true)
        let trackingAccount = Account(name: "Mortgage", type: .mortgage, isBudget: false)
        context.insert(budgetAccount)
        context.insert(trackingAccount)

        // Seed budget account
        let income = Transaction(amount: Decimal(2000), payee: "Employer", type: .income)
        income.account = budgetAccount
        context.insert(income)

        // Transfer from budget to tracking
        let transfer = Transaction(amount: Decimal(800), payee: "Mortgage Payment", type: .transfer)
        transfer.account = budgetAccount
        transfer.transferToAccount = trackingAccount
        context.insert(transfer)
        try context.save()

        #expect(budgetAccount.balance == Decimal(1200))
        #expect(trackingAccount.balance == Decimal(800))
    }

    @MainActor @Test("Multiple transactions of different types produce correct balance")
    func mixedTransactions() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Main", type: .current)
        context.insert(account)

        let otherAccount = Account(name: "Savings", type: .savings)
        context.insert(otherAccount)

        // Income: +3000
        let income = Transaction(amount: Decimal(3000), payee: "Salary", type: .income)
        income.account = account
        context.insert(income)

        // Expense: -150
        let expense1 = Transaction(amount: Decimal(150), payee: "Groceries", type: .expense)
        expense1.account = account
        context.insert(expense1)

        // Expense: -50
        let expense2 = Transaction(amount: Decimal(50), payee: "Coffee", type: .expense)
        expense2.account = account
        context.insert(expense2)

        // Transfer out: -500
        let transferOut = Transaction(amount: Decimal(500), payee: "Transfer", type: .transfer)
        transferOut.account = account
        transferOut.transferToAccount = otherAccount
        context.insert(transferOut)

        try context.save()

        // 3000 - 150 - 50 - 500 = 2300
        #expect(account.balance == Decimal(2300))
        // Other account receives the transfer: 500
        #expect(otherAccount.balance == Decimal(500))
    }
}

// MARK: - Account Type Tests

@Suite("Account type defaults")
struct AccountTypeTests {

    @Test("Current, savings, credit card default to budget accounts")
    func budgetDefaults() {
        #expect(AccountType.current.defaultIsBudget == true)
        #expect(AccountType.savings.defaultIsBudget == true)
        #expect(AccountType.creditCard.defaultIsBudget == true)
    }

    @Test("Loan, mortgage, asset, liability default to tracking accounts")
    func trackingDefaults() {
        #expect(AccountType.loan.defaultIsBudget == false)
        #expect(AccountType.mortgage.defaultIsBudget == false)
        #expect(AccountType.asset.defaultIsBudget == false)
        #expect(AccountType.liability.defaultIsBudget == false)
    }

    @Test("AccountType decoding handles legacy 'Checking' value")
    func legacyCheckingDecoding() throws {
        let json = "\"Checking\""
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AccountType.self, from: data)
        #expect(decoded == .current)
    }

    @Test("AccountType decoding handles legacy 'Cash' value")
    func legacyCashDecoding() throws {
        let json = "\"Cash\""
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AccountType.self, from: data)
        #expect(decoded == .current)
    }
}

// MARK: - Transaction Type Tests

@Suite("Transaction type behaviour")
struct TransactionTypeTests {

    @MainActor @Test("transferNeedsCategory is true for cross-boundary transfers")
    func crossBoundaryTransferNeedsCategory() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let budget = Account(name: "Current", type: .current, isBudget: true)
        let tracking = Account(name: "Loan", type: .loan, isBudget: false)
        context.insert(budget)
        context.insert(tracking)

        let transfer = Transaction(amount: Decimal(100), payee: "Payment", type: .transfer)
        transfer.account = budget
        transfer.transferToAccount = tracking
        context.insert(transfer)
        try context.save()

        #expect(transfer.transferNeedsCategory == true)
    }

    @MainActor @Test("transferNeedsCategory is false for same-boundary transfers")
    func sameBoundaryTransferDoesNotNeedCategory() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let checking = Account(name: "Checking", type: .current, isBudget: true)
        let savings = Account(name: "Savings", type: .savings, isBudget: true)
        context.insert(checking)
        context.insert(savings)

        let transfer = Transaction(amount: Decimal(100), payee: "Move", type: .transfer)
        transfer.account = checking
        transfer.transferToAccount = savings
        context.insert(transfer)
        try context.save()

        #expect(transfer.transferNeedsCategory == false)
    }

    @MainActor @Test("transferNeedsCategory is false for non-transfer types")
    func nonTransferDoesNotNeedCategory() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current)
        context.insert(account)

        let expense = Transaction(amount: Decimal(50), payee: "Shop", type: .expense)
        expense.account = account
        context.insert(expense)
        try context.save()

        #expect(expense.transferNeedsCategory == false)
    }

    @MainActor @Test("Cleared vs uncleared flag is preserved")
    func clearedFlag() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current)
        context.insert(account)

        let cleared = Transaction(amount: Decimal(100), payee: "A", type: .expense, isCleared: true)
        cleared.account = account
        context.insert(cleared)

        let uncleared = Transaction(amount: Decimal(50), payee: "B", type: .expense, isCleared: false)
        uncleared.account = account
        context.insert(uncleared)
        try context.save()

        #expect(cleared.isCleared == true)
        #expect(uncleared.isCleared == false)
        // Both affect the balance regardless of cleared status
        #expect(account.balance == Decimal(-150))
    }
}
