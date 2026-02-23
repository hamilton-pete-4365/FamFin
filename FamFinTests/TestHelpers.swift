import Foundation
import SwiftData
import Testing
@testable import FamFin

// Disambiguate FamFin.Category from ObjC's Category typedef
typealias BudgetCategory = FamFin.Category

// MARK: - In-Memory ModelContainer Factory

/// Creates a fresh in-memory ModelContainer for testing.
/// Each test should call this to get an isolated database.
@MainActor
func makeTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Account.self,
             Transaction.self,
             Category.self,
             BudgetMonth.self,
             BudgetAllocation.self,
             Payee.self,
             RecurringTransaction.self,
        configurations: config
    )
}

// MARK: - Date Helpers

/// Creates a Date for the first day of the given year and month.
func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = 12 // noon to avoid timezone edge cases
    return Calendar.current.date(from: components)!
}

/// Returns the first day of the month for a given date, normalised.
func startOfMonth(_ date: Date) -> Date {
    let calendar = Calendar.current
    let comps = calendar.dateComponents([.year, .month], from: date)
    return calendar.date(from: comps)!
}
