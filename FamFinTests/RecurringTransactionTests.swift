import Foundation
import SwiftData
import Testing
@testable import FamFin

// MARK: - RecurrenceFrequency Tests

@Suite("RecurrenceFrequency")
struct RecurrenceFrequencyTests {

    @Test("Daily advances by one day")
    func dailyAdvance() {
        let date = makeDate(year: 2025, month: 3, day: 10)
        let next = RecurrenceFrequency.daily.nextDate(after: date)
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: next)
        #expect(comps.year == 2025)
        #expect(comps.month == 3)
        #expect(comps.day == 11)
    }

    @Test("Weekly advances by seven days")
    func weeklyAdvance() {
        let date = makeDate(year: 2025, month: 3, day: 10)
        let next = RecurrenceFrequency.weekly.nextDate(after: date)
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: next)
        #expect(comps.year == 2025)
        #expect(comps.month == 3)
        #expect(comps.day == 17)
    }

    @Test("Biweekly advances by fourteen days")
    func biweeklyAdvance() {
        let date = makeDate(year: 2025, month: 3, day: 10)
        let next = RecurrenceFrequency.biweekly.nextDate(after: date)
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: next)
        #expect(comps.year == 2025)
        #expect(comps.month == 3)
        #expect(comps.day == 24)
    }

    @Test("Monthly advances by one month")
    func monthlyAdvance() {
        let date = makeDate(year: 2025, month: 3, day: 15)
        let next = RecurrenceFrequency.monthly.nextDate(after: date)
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: next)
        #expect(comps.year == 2025)
        #expect(comps.month == 4)
        #expect(comps.day == 15)
    }

    @Test("Monthly handles December to January rollover")
    func monthlyDecemberRollover() {
        let date = makeDate(year: 2025, month: 12, day: 15)
        let next = RecurrenceFrequency.monthly.nextDate(after: date)
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: next)
        #expect(comps.year == 2026)
        #expect(comps.month == 1)
        #expect(comps.day == 15)
    }

    @Test("Yearly advances by one year")
    func yearlyAdvance() {
        let date = makeDate(year: 2025, month: 6, day: 1)
        let next = RecurrenceFrequency.yearly.nextDate(after: date)
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: next)
        #expect(comps.year == 2026)
        #expect(comps.month == 6)
    }

    @Test("All cases are iterable")
    func allCases() {
        #expect(RecurrenceFrequency.allCases.count == 5)
    }

    @Test("Display names match raw values")
    func displayNames() {
        for freq in RecurrenceFrequency.allCases {
            #expect(freq.displayName == freq.rawValue)
        }
    }
}

// MARK: - RecurringTransaction Model Tests

@Suite("RecurringTransaction model")
struct RecurringTransactionModelTests {

    @MainActor @Test("Default property values for CloudKit compatibility")
    func defaultPropertyValues() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let recurring = RecurringTransaction(amount: 50, payee: "Netflix")
        context.insert(recurring)
        try context.save()

        #expect(recurring.amount == 50)
        #expect(recurring.payee == "Netflix")
        #expect(recurring.memo == "")
        #expect(recurring.type == .expense)
        #expect(recurring.frequency == .monthly)
        #expect(recurring.isActive == true)
        #expect(recurring.endDate == nil)
        #expect(recurring.account == nil)
        #expect(recurring.category == nil)
        #expect(recurring.transferToAccount == nil)
    }

    @MainActor @Test("nextOccurrence defaults to startDate")
    func nextOccurrenceDefaultsToStart() throws {
        let start = makeDate(year: 2025, month: 6, day: 15)
        let recurring = RecurringTransaction(
            amount: 100,
            payee: "Rent",
            startDate: start
        )

        let container = try makeTestContainer()
        let context = container.mainContext
        context.insert(recurring)
        try context.save()

        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: recurring.nextOccurrence)
        #expect(comps.year == 2025)
        #expect(comps.month == 6)
        #expect(comps.day == 15)
    }

    @MainActor @Test("Relationships link to account and category")
    func relationshipsLink() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current)
        let category = BudgetCategory(name: "Subscriptions", emoji: "📺")
        context.insert(account)
        context.insert(category)

        let recurring = RecurringTransaction(amount: 15, payee: "Spotify")
        recurring.account = account
        recurring.category = category
        context.insert(recurring)
        try context.save()

        #expect(recurring.account?.name == "Current")
        #expect(recurring.category?.name == "Subscriptions")
    }

    @MainActor @Test("Transfer type links to destination account")
    func transferLinksDestination() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let from = Account(name: "Current", type: .current, isBudget: true)
        let to = Account(name: "Savings", type: .savings, isBudget: true)
        context.insert(from)
        context.insert(to)

        let recurring = RecurringTransaction(
            amount: 200,
            payee: "Transfer",
            type: .transfer
        )
        recurring.account = from
        recurring.transferToAccount = to
        context.insert(recurring)
        try context.save()

        #expect(recurring.transferToAccount?.name == "Savings")
    }

    @MainActor @Test("Inverse relationships are accessible from Account")
    func inverseRelationshipsOnAccount() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current)
        context.insert(account)

        let recurring = RecurringTransaction(amount: 50, payee: "Netflix")
        recurring.account = account
        context.insert(recurring)
        try context.save()

        #expect(account.recurringTransactions.count == 1)
        #expect(account.recurringTransactions.first?.payee == "Netflix")
    }

    @MainActor @Test("Inverse relationships are accessible from Category")
    func inverseRelationshipsOnCategory() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let category = BudgetCategory(name: "Subscriptions", emoji: "📺")
        context.insert(category)

        let recurring = RecurringTransaction(amount: 15, payee: "Spotify")
        recurring.category = category
        context.insert(recurring)
        try context.save()

        #expect(category.recurringTransactions.count == 1)
        #expect(category.recurringTransactions.first?.payee == "Spotify")
    }
}
