import Foundation
import SwiftData
import Testing
@testable import FamFin

// MARK: - DataExporter JSON Export Tests

@Suite("DataExporter - JSON export")
struct DataExporterExportTests {

    @MainActor @Test("Export produces valid JSON")
    func exportProducesValidJSON() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        // Insert some data
        let account = Account(name: "Current", type: .current, isBudget: true)
        context.insert(account)

        let category = Category(name: "Groceries", emoji: "🛒")
        context.insert(category)

        let tx = Transaction(amount: Decimal(50), payee: "Shop", type: .expense)
        tx.account = account
        tx.category = category
        context.insert(tx)
        try context.save()

        let data = try DataExporter.exportJSON(context: context)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json != nil)
    }

    @MainActor @Test("Export contains all expected top-level keys")
    func exportContainsExpectedKeys() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current)
        context.insert(account)
        try context.save()

        let data = try DataExporter.exportJSON(context: context)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["exportDate"] != nil)
        #expect(json["appVersion"] != nil)
        #expect(json["accounts"] != nil)
        #expect(json["transactions"] != nil)
        #expect(json["categories"] != nil)
        #expect(json["budgetMonths"] != nil)
        #expect(json["budgetAllocations"] != nil)
        #expect(json["payees"] != nil)
    }

    @MainActor @Test("Export accounts contain correct fields")
    func exportAccountsCorrectFields() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Savings", type: .savings, isBudget: true, sortOrder: 2)
        context.insert(account)
        try context.save()

        let data = try DataExporter.exportJSON(context: context)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let accounts = json["accounts"] as! [[String: Any]]

        #expect(accounts.count == 1)
        let exported = accounts[0]
        #expect(exported["name"] as? String == "Savings")
        #expect(exported["type"] as? String == "Savings")
        #expect(exported["isBudget"] as? Bool == true)
        #expect(exported["sortOrder"] as? Int == 2)
        #expect(exported["createdAt"] != nil)
    }

    @MainActor @Test("Export categories preserve hierarchy via parentName")
    func exportCategoryHierarchy() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let header = Category(name: "Monthly", emoji: "📅", isHeader: true)
        context.insert(header)

        let sub = Category(name: "Groceries", emoji: "🛒")
        sub.parent = header
        context.insert(sub)
        try context.save()

        let data = try DataExporter.exportJSON(context: context)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let categories = json["categories"] as! [[String: Any]]

        // Find the subcategory
        let groceryExport = categories.first { ($0["name"] as? String) == "Groceries" }
        #expect(groceryExport != nil)
        #expect(groceryExport?["parentName"] as? String == "Monthly")
    }

    @MainActor @Test("Export transactions include account and category names")
    func exportTransactionRelationships() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current)
        context.insert(account)

        let header = Category(name: "Monthly", isHeader: true)
        context.insert(header)
        let category = Category(name: "Groceries")
        category.parent = header
        context.insert(category)

        let tx = Transaction(amount: Decimal(75), payee: "Shop", type: .expense)
        tx.account = account
        tx.category = category
        context.insert(tx)
        try context.save()

        let data = try DataExporter.exportJSON(context: context)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let transactions = json["transactions"] as! [[String: Any]]

        let exported = transactions[0]
        #expect(exported["accountName"] as? String == "Current")
        #expect(exported["categoryName"] as? String == "Groceries")
        #expect(exported["categoryParent"] as? String == "Monthly")
        #expect(exported["amount"] as? String == "75")
        #expect(exported["type"] as? String == "Expense")
    }

    @MainActor @Test("Export transfers include transferToAccountName")
    func exportTransferDestination() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let from = Account(name: "Checking", type: .current)
        let to = Account(name: "Savings", type: .savings)
        context.insert(from)
        context.insert(to)

        let tx = Transaction(amount: Decimal(200), payee: "Transfer", type: .transfer)
        tx.account = from
        tx.transferToAccount = to
        context.insert(tx)
        try context.save()

        let data = try DataExporter.exportJSON(context: context)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let transactions = json["transactions"] as! [[String: Any]]

        #expect(transactions[0]["transferToAccountName"] as? String == "Savings")
    }

    @MainActor @Test("Export payees include use count and last used category")
    func exportPayees() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let category = Category(name: "Groceries")
        context.insert(category)

        let payee = Payee(name: "Supermarket", lastUsedCategory: category)
        payee.useCount = 5
        context.insert(payee)
        try context.save()

        let data = try DataExporter.exportJSON(context: context)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let payees = json["payees"] as! [[String: Any]]

        #expect(payees.count == 1)
        #expect(payees[0]["name"] as? String == "Supermarket")
        #expect(payees[0]["useCount"] as? Int == 5)
        #expect(payees[0]["lastUsedCategoryName"] as? String == "Groceries")
    }

    @MainActor @Test("Empty database exports empty arrays")
    func emptyDatabaseExport() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let data = try DataExporter.exportJSON(context: context)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect((json["accounts"] as! [Any]).isEmpty)
        #expect((json["transactions"] as! [Any]).isEmpty)
        #expect((json["categories"] as! [Any]).isEmpty)
    }
}

// MARK: - DataExporter JSON Import Tests

@Suite("DataExporter - JSON import")
struct DataExporterImportTests {

    @MainActor @Test("Import creates accounts from JSON")
    func importCreatesAccounts() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let json: [String: Any] = [
            "exportDate": "2025-03-01T00:00:00Z",
            "appVersion": "1.0",
            "accounts": [
                [
                    "name": "Current",
                    "type": "Current",
                    "isBudget": true,
                    "sortOrder": 0,
                    "createdAt": "2025-01-01T00:00:00Z"
                ]
            ],
            "transactions": [],
            "categories": [],
            "budgetMonths": [],
            "budgetAllocations": [],
            "payees": []
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let url = FileManager.default.temporaryDirectory.appending(path: "test-import.json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        try DataExporter.importJSON(from: url, context: context)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        #expect(accounts.count == 1)
        #expect(accounts[0].name == "Current")
        #expect(accounts[0].type == .current)
        #expect(accounts[0].isBudget == true)
    }

    @MainActor @Test("Import creates categories with hierarchy")
    func importCategoryHierarchy() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let json: [String: Any] = [
            "exportDate": "2025-03-01T00:00:00Z",
            "appVersion": "1.0",
            "accounts": [],
            "transactions": [],
            "categories": [
                [
                    "name": "Monthly",
                    "emoji": "📅",
                    "isHeader": true,
                    "isSystem": false,
                    "sortOrder": 0
                ],
                [
                    "name": "Groceries",
                    "emoji": "🛒",
                    "isHeader": false,
                    "isSystem": false,
                    "sortOrder": 0,
                    "parentName": "Monthly"
                ],
                [
                    "name": "Utilities",
                    "emoji": "💡",
                    "isHeader": false,
                    "isSystem": false,
                    "sortOrder": 1,
                    "parentName": "Monthly"
                ]
            ],
            "budgetMonths": [],
            "budgetAllocations": [],
            "payees": []
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let url = FileManager.default.temporaryDirectory.appending(path: "test-import-cats.json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        try DataExporter.importJSON(from: url, context: context)

        let categories = try context.fetch(FetchDescriptor<FamFin.Category>())
        #expect(categories.count == 3)

        let header = categories.first { $0.isHeader }
        #expect(header?.name == "Monthly")

        let groceries = categories.first { $0.name == "Groceries" }
        #expect(groceries?.parent?.name == "Monthly")

        let utilities = categories.first { $0.name == "Utilities" }
        #expect(utilities?.parent?.name == "Monthly")
    }

    @MainActor @Test("Import links transactions to accounts and categories")
    func importTransactionRelationships() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let json: [String: Any] = [
            "exportDate": "2025-03-01T00:00:00Z",
            "appVersion": "1.0",
            "accounts": [
                ["name": "Current", "type": "Current", "isBudget": true, "sortOrder": 0, "createdAt": "2025-01-01T00:00:00Z"]
            ],
            "transactions": [
                [
                    "amount": "99.50",
                    "payee": "Supermarket",
                    "memo": "Weekly shop",
                    "date": "2025-03-15T12:00:00Z",
                    "type": "Expense",
                    "isCleared": true,
                    "accountName": "Current",
                    "categoryName": "Groceries",
                    "categoryParent": "Monthly"
                ]
            ],
            "categories": [
                ["name": "Monthly", "emoji": "📅", "isHeader": true, "isSystem": false, "sortOrder": 0],
                ["name": "Groceries", "emoji": "🛒", "isHeader": false, "isSystem": false, "sortOrder": 0, "parentName": "Monthly"]
            ],
            "budgetMonths": [],
            "budgetAllocations": [],
            "payees": []
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let url = FileManager.default.temporaryDirectory.appending(path: "test-import-tx.json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        try DataExporter.importJSON(from: url, context: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        #expect(transactions.count == 1)

        let tx = transactions[0]
        #expect(tx.amount == Decimal(string: "99.50"))
        #expect(tx.payee == "Supermarket")
        #expect(tx.memo == "Weekly shop")
        #expect(tx.type == .expense)
        #expect(tx.isCleared == true)
        #expect(tx.account?.name == "Current")
        #expect(tx.category?.name == "Groceries")
    }

    @MainActor @Test("Import links transfers to destination account")
    func importTransferLink() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let json: [String: Any] = [
            "exportDate": "2025-03-01T00:00:00Z",
            "appVersion": "1.0",
            "accounts": [
                ["name": "Current", "type": "Current", "isBudget": true, "sortOrder": 0, "createdAt": "2025-01-01T00:00:00Z"],
                ["name": "Savings", "type": "Savings", "isBudget": true, "sortOrder": 1, "createdAt": "2025-01-01T00:00:00Z"]
            ],
            "transactions": [
                [
                    "amount": "500",
                    "payee": "Transfer",
                    "memo": "",
                    "date": "2025-03-15T12:00:00Z",
                    "type": "Transfer",
                    "isCleared": false,
                    "accountName": "Current",
                    "transferToAccountName": "Savings"
                ]
            ],
            "categories": [],
            "budgetMonths": [],
            "budgetAllocations": [],
            "payees": []
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let url = FileManager.default.temporaryDirectory.appending(path: "test-import-transfer.json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        try DataExporter.importJSON(from: url, context: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        #expect(transactions.count == 1)
        #expect(transactions[0].account?.name == "Current")
        #expect(transactions[0].transferToAccount?.name == "Savings")
    }

    @MainActor @Test("Import budget allocations linked to months and categories")
    func importAllocations() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let json: [String: Any] = [
            "exportDate": "2025-03-01T00:00:00Z",
            "appVersion": "1.0",
            "accounts": [],
            "transactions": [],
            "categories": [
                ["name": "Groceries", "emoji": "🛒", "isHeader": false, "isSystem": false, "sortOrder": 0]
            ],
            "budgetMonths": [
                ["month": "2025-03-01T00:00:00Z", "note": "March"]
            ],
            "budgetAllocations": [
                [
                    "budgeted": "300",
                    "categoryName": "Groceries",
                    "month": "2025-03-01T00:00:00Z"
                ]
            ],
            "payees": []
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let url = FileManager.default.temporaryDirectory.appending(path: "test-import-alloc.json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        try DataExporter.importJSON(from: url, context: context)

        let allocations = try context.fetch(FetchDescriptor<BudgetAllocation>())
        #expect(allocations.count == 1)
        #expect(allocations[0].budgeted == Decimal(300))
        #expect(allocations[0].category?.name == "Groceries")
        #expect(allocations[0].budgetMonth != nil)
    }

    @MainActor @Test("Import replaces existing data (full replace)")
    func importReplacesExistingData() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        // Pre-existing data
        let existingAccount = Account(name: "OldAccount", type: .current)
        context.insert(existingAccount)
        try context.save()

        let json: [String: Any] = [
            "exportDate": "2025-03-01T00:00:00Z",
            "appVersion": "1.0",
            "accounts": [
                ["name": "NewAccount", "type": "Current", "isBudget": true, "sortOrder": 0, "createdAt": "2025-01-01T00:00:00Z"]
            ],
            "transactions": [],
            "categories": [],
            "budgetMonths": [],
            "budgetAllocations": [],
            "payees": []
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let url = FileManager.default.temporaryDirectory.appending(path: "test-import-replace.json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        try DataExporter.importJSON(from: url, context: context)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        #expect(accounts.count == 1)
        #expect(accounts[0].name == "NewAccount")
    }

    @MainActor @Test("Import rejects invalid JSON format")
    func importRejectsInvalidFormat() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let invalidData = "not json".data(using: .utf8)!
        let url = FileManager.default.temporaryDirectory.appending(path: "test-import-invalid.json")
        try invalidData.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: Error.self) {
            try DataExporter.importJSON(from: url, context: context)
        }
    }

    @MainActor @Test("Import imports payees with category links")
    func importPayees() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let json: [String: Any] = [
            "exportDate": "2025-03-01T00:00:00Z",
            "appVersion": "1.0",
            "accounts": [],
            "transactions": [],
            "categories": [
                ["name": "Groceries", "emoji": "🛒", "isHeader": false, "isSystem": false, "sortOrder": 0]
            ],
            "budgetMonths": [],
            "budgetAllocations": [],
            "payees": [
                [
                    "name": "Supermarket",
                    "lastUsedDate": "2025-03-01T12:00:00Z",
                    "useCount": 10,
                    "lastUsedCategoryName": "Groceries"
                ]
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let url = FileManager.default.temporaryDirectory.appending(path: "test-import-payees.json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        try DataExporter.importJSON(from: url, context: context)

        let payees = try context.fetch(FetchDescriptor<Payee>())
        #expect(payees.count == 1)
        #expect(payees[0].name == "Supermarket")
        #expect(payees[0].useCount == 10)
        #expect(payees[0].lastUsedCategory?.name == "Groceries")
    }
}

// MARK: - DataExporter Round-Trip Tests

@Suite("DataExporter - round-trip")
struct DataExporterRoundTripTests {

    @MainActor @Test("Export then import preserves account data")
    func roundTripAccounts() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Main Account", type: .savings, isBudget: false, sortOrder: 3)
        context.insert(account)
        try context.save()

        // Export
        let data = try DataExporter.exportJSON(context: context)

        // Write to temp file
        let url = FileManager.default.temporaryDirectory.appending(path: "roundtrip-accounts.json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        // Import into same context (it deletes first)
        try DataExporter.importJSON(from: url, context: context)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        #expect(accounts.count == 1)
        #expect(accounts[0].name == "Main Account")
        #expect(accounts[0].type == .savings)
        #expect(accounts[0].isBudget == false)
        #expect(accounts[0].sortOrder == 3)
    }

    @MainActor @Test("Export then import preserves category hierarchy")
    func roundTripCategoryHierarchy() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let header = Category(name: "Fun", emoji: "🎉", isHeader: true, sortOrder: 0)
        context.insert(header)

        let holiday = Category(name: "Holiday", emoji: "✈️", sortOrder: 0)
        holiday.parent = header
        context.insert(holiday)

        let music = Category(name: "Music", emoji: "🎵", sortOrder: 1)
        music.parent = header
        context.insert(music)
        try context.save()

        let data = try DataExporter.exportJSON(context: context)
        let url = FileManager.default.temporaryDirectory.appending(path: "roundtrip-cats.json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        try DataExporter.importJSON(from: url, context: context)

        let categories = try context.fetch(FetchDescriptor<FamFin.Category>())
        let headerImported = categories.first { $0.isHeader && $0.name == "Fun" }
        #expect(headerImported != nil)

        let holidayImported = categories.first { $0.name == "Holiday" }
        #expect(holidayImported?.parent?.name == "Fun")

        let musicImported = categories.first { $0.name == "Music" }
        #expect(musicImported?.parent?.name == "Fun")
    }

    @MainActor @Test("Export then import preserves transaction amounts as Decimal")
    func roundTripDecimalPrecision() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = Account(name: "Current", type: .current)
        context.insert(account)

        let tx = Transaction(amount: Decimal(string: "99.99")!, payee: "Shop", type: .expense)
        tx.account = account
        context.insert(tx)
        try context.save()

        let data = try DataExporter.exportJSON(context: context)
        let url = FileManager.default.temporaryDirectory.appending(path: "roundtrip-decimal.json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        try DataExporter.importJSON(from: url, context: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        #expect(transactions.count == 1)
        #expect(transactions[0].amount == Decimal(string: "99.99"))
    }
}
