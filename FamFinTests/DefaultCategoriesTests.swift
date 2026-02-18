import Foundation
import SwiftData
import Testing
@testable import FamFin

// MARK: - DefaultCategories Tests

@Suite("DefaultCategories seeding")
struct DefaultCategoriesTests {

    @MainActor @Test("seedIfNeeded creates To Budget system category")
    func createsSystemCategory() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        DefaultCategories.seedIfNeeded(context: context)

        let categories = try context.fetch(FetchDescriptor<FamFin.Category>())
        let systemCats = categories.filter { $0.isSystem }
        #expect(systemCats.count == 1)
        #expect(systemCats[0].name == "To Budget")
    }

    @MainActor @Test("seedIfNeeded creates header categories on fresh install")
    func createsHeaderCategories() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        DefaultCategories.seedIfNeeded(context: context)

        let categories = try context.fetch(FetchDescriptor<FamFin.Category>())
        let headers = categories.filter { $0.isHeader }

        // Should have one header per DefaultCategories.all entry
        #expect(headers.count == DefaultCategories.all.count)

        let headerNames = Set(headers.map { $0.name })
        for def in DefaultCategories.all {
            #expect(headerNames.contains(def.name), Comment(rawValue: "Missing header: \(def.name)"))
        }
    }

    @MainActor @Test("seedIfNeeded creates subcategories under headers")
    func createsSubcategories() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        DefaultCategories.seedIfNeeded(context: context)

        let categories = try context.fetch(FetchDescriptor<FamFin.Category>())
        let subcategories = categories.filter { !$0.isHeader && !$0.isSystem }

        // Each subcategory should have a parent
        for sub in subcategories {
            #expect(sub.parent != nil, Comment(rawValue: "Subcategory \(sub.name) should have a parent"))
        }

        // Count total expected subcategories
        let expectedSubCount = DefaultCategories.all.reduce(0) { $0 + $1.subcategories.count }
        #expect(subcategories.count == expectedSubCount)
    }

    @MainActor @Test("seedIfNeeded is idempotent (running twice doesn't duplicate)")
    func idempotent() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        DefaultCategories.seedIfNeeded(context: context)
        let firstCount = try context.fetch(FetchDescriptor<FamFin.Category>()).count

        DefaultCategories.seedIfNeeded(context: context)
        let secondCount = try context.fetch(FetchDescriptor<FamFin.Category>()).count

        #expect(firstCount == secondCount)
    }

    @MainActor @Test("toBudgetName constant is 'To Budget'")
    func toBudgetNameConstant() {
        #expect(DefaultCategories.toBudgetName == "To Budget")
    }
}
