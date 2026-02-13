import Foundation
import SwiftData

/// Seeds the database with default budget categories on first launch.
/// Also handles migration from the old flat category system to the new header/subcategory hierarchy.
struct DefaultCategories {

    /// Name used for the system "To Budget" category
    static let toBudgetName = "To Budget"

    struct HeaderDef {
        let name: String
        let emoji: String
        let subcategories: [(name: String, emoji: String)]
    }

    static let all: [HeaderDef] = [
        HeaderDef(name: "Charity", emoji: "❤️", subcategories: [
            ("Regular Donations", "🎗️"),
            ("Ad Hoc Donations", "🤝"),
        ]),
        HeaderDef(name: "Debt", emoji: "💳", subcategories: [
            ("Mortgage", "🏠"),
            ("Loan", "🏦"),
        ]),
        HeaderDef(name: "Monthly", emoji: "📅", subcategories: [
            ("Groceries", "🛒"),
            ("Utilities", "💡"),
            ("Travel", "🚗"),
        ]),
        HeaderDef(name: "Longer Term", emoji: "📆", subcategories: [
            ("Council Tax", "🏛️"),
            ("Water", "💧"),
            ("Car & Bike", "🚙"),
            ("Weddings & Birthdays", "🎂"),
            ("Home", "🏡"),
            ("Clothes", "👔"),
            ("Christmas", "🎄"),
            ("Health", "🏥"),
            ("Subscriptions", "📱"),
        ]),
        HeaderDef(name: "Fun", emoji: "🎉", subcategories: [
            ("Holiday", "✈️"),
            ("Family Fun", "👨‍👩‍👧‍👦"),
            ("Eating & Drinking", "🍽️"),
            ("Getting Outside", "🌳"),
            ("Music", "🎵"),
        ]),
        HeaderDef(name: "Future", emoji: "🔮", subcategories: [
            ("New Car", "🚗"),
            ("Home", "🏠"),
            ("Career", "💼"),
        ]),
    ]

    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Category>()
        let existingCategories = (try? context.fetch(descriptor)) ?? []

        // Always ensure the "To Budget" system category exists
        ensureToBudgetCategory(existing: existingCategories, context: context)

        // Seed user categories if needed
        let nonSystem = existingCategories.filter { !$0.isSystem }
        if nonSystem.isEmpty {
            // Fresh install — seed the full hierarchy
            seedFreshHierarchy(context: context)
        } else if nonSystem.allSatisfy({ !$0.isHeader && $0.parent == nil }) {
            // Old flat categories detected — migrate into new hierarchy
            migrateOldCategories(existing: nonSystem, context: context)
        }
        // else: already has hierarchy — do nothing

        try? context.save()
    }

    // MARK: - System category: To Budget

    /// Ensures the "To Budget" system category exists. Creates it if not found.
    private static func ensureToBudgetCategory(existing: [Category], context: ModelContext) {
        let hasSystem = existing.contains { $0.isSystem && $0.name == toBudgetName }
        if !hasSystem {
            let toBudget = Category(name: toBudgetName, emoji: "💰", isHeader: false, isSystem: true, sortOrder: -1)
            context.insert(toBudget)
        }
    }

    // MARK: - Fresh install seeding

    private static func seedFreshHierarchy(context: ModelContext) {
        for (headerIndex, headerDef) in all.enumerated() {
            let header = Category(name: headerDef.name, emoji: headerDef.emoji, isHeader: true, sortOrder: headerIndex)
            context.insert(header)

            for (subIndex, subDef) in headerDef.subcategories.enumerated() {
                let sub = Category(name: subDef.name, emoji: subDef.emoji, isHeader: false, sortOrder: subIndex)
                sub.parent = header
                context.insert(sub)
            }
        }
    }

    // MARK: - Migration from old flat categories

    private static func migrateOldCategories(existing: [Category], context: ModelContext) {
        // Create all header categories
        var headers: [String: Category] = [:]
        for (headerIndex, headerDef) in all.enumerated() {
            let header = Category(name: headerDef.name, emoji: headerDef.emoji, isHeader: true, sortOrder: headerIndex)
            context.insert(header)
            headers[headerDef.name] = header
        }

        // Map old category names to their appropriate new header.
        let nameToHeader: [String: String] = [
            "Rent / Mortgage": "Debt",
            "Groceries": "Monthly",
            "Bills & Utilities": "Monthly",
            "Transport": "Monthly",
            "Insurance": "Longer Term",
            "Health": "Longer Term",
            "Eating Out": "Fun",
            "Entertainment": "Fun",
            "Shopping": "Longer Term",
            "Subscriptions": "Longer Term",
            "Hobbies": "Fun",
            "Holiday": "Fun",
            "Emergency Fund": "Future",
            "Savings": "Future",
            "Debt Repayment": "Debt",
        ]

        // Assign existing categories as children of headers
        for category in existing {
            let headerName = nameToHeader[category.name] ?? "Monthly"
            category.parent = headers[headerName]
        }

        // Seed any NEW subcategories that didn't exist in the old set
        let existingNames = Set(existing.map { $0.name })
        for headerDef in all {
            guard let header = headers[headerDef.name] else { continue }
            let existingChildCount = existing.filter { $0.parent?.persistentModelID == header.persistentModelID }.count
            var nextSort = existingChildCount

            for subDef in headerDef.subcategories {
                if !existingNames.contains(subDef.name) {
                    let sub = Category(name: subDef.name, emoji: subDef.emoji, isHeader: false, sortOrder: nextSort)
                    sub.parent = header
                    context.insert(sub)
                    nextSort += 1
                }
            }
        }
    }
}
