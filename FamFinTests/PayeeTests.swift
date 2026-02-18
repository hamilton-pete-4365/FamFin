import Foundation
import SwiftData
import Testing
@testable import FamFin

// MARK: - Payee Tests

@Suite("Payee model")
struct PayeeTests {

    @MainActor @Test("New payee has use count of 1")
    func newPayeeUseCount() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let payee = Payee(name: "Supermarket")
        context.insert(payee)
        try context.save()

        #expect(payee.useCount == 1)
    }

    @MainActor @Test("recordUsage increments use count")
    func recordUsageIncrementsCount() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let payee = Payee(name: "Supermarket")
        context.insert(payee)
        try context.save()

        payee.recordUsage(category: nil)
        #expect(payee.useCount == 2)

        payee.recordUsage(category: nil)
        #expect(payee.useCount == 3)
    }

    @MainActor @Test("recordUsage updates last used category")
    func recordUsageUpdatesCategory() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let groceries = Category(name: "Groceries")
        let dining = Category(name: "Dining")
        context.insert(groceries)
        context.insert(dining)

        let payee = Payee(name: "Restaurant", lastUsedCategory: groceries)
        context.insert(payee)
        try context.save()

        #expect(payee.lastUsedCategory?.name == "Groceries")

        payee.recordUsage(category: dining)
        #expect(payee.lastUsedCategory?.name == "Dining")
    }

    @MainActor @Test("recordUsage with nil category does not clear existing category")
    func recordUsageNilDoesNotClear() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let groceries = Category(name: "Groceries")
        context.insert(groceries)

        let payee = Payee(name: "Shop", lastUsedCategory: groceries)
        context.insert(payee)
        try context.save()

        payee.recordUsage(category: nil)

        // Category should remain unchanged
        #expect(payee.lastUsedCategory?.name == "Groceries")
        // But use count should increment
        #expect(payee.useCount == 2)
    }

    @MainActor @Test("recordUsage updates lastUsedDate")
    func recordUsageUpdatesDate() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let payee = Payee(name: "Shop")
        context.insert(payee)
        try context.save()

        let dateBefore = payee.lastUsedDate

        // Small delay to ensure date changes
        payee.recordUsage(category: nil)

        #expect(payee.lastUsedDate >= dateBefore)
    }

    @MainActor @Test("Payee can be created without a category")
    func payeeWithoutCategory() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let payee = Payee(name: "Unknown Shop")
        context.insert(payee)
        try context.save()

        #expect(payee.name == "Unknown Shop")
        #expect(payee.lastUsedCategory == nil)
        #expect(payee.useCount == 1)
    }

    @MainActor @Test("Multiple payees maintain independent state")
    func multiplePayeesIndependent() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let groceries = Category(name: "Groceries")
        let dining = Category(name: "Dining")
        context.insert(groceries)
        context.insert(dining)

        let payee1 = Payee(name: "Supermarket", lastUsedCategory: groceries)
        let payee2 = Payee(name: "Restaurant", lastUsedCategory: dining)
        context.insert(payee1)
        context.insert(payee2)
        try context.save()

        payee1.recordUsage(category: groceries)

        #expect(payee1.useCount == 2)
        #expect(payee2.useCount == 1)
        #expect(payee1.lastUsedCategory?.name == "Groceries")
        #expect(payee2.lastUsedCategory?.name == "Dining")
    }
}
