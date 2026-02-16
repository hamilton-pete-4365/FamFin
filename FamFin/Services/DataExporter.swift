import Foundation
import SwiftData

/// Exports all app data as a JSON file for backup purposes.
struct DataExporter {

    /// Generate a JSON Data blob containing all app data.
    static func exportJSON(context: ModelContext) throws -> Data {
        // Fetch all entities
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let budgetMonths = (try? context.fetch(FetchDescriptor<BudgetMonth>())) ?? []
        let allocations = (try? context.fetch(FetchDescriptor<BudgetAllocation>())) ?? []
        let payees = (try? context.fetch(FetchDescriptor<Payee>())) ?? []

        let dateFormatter = ISO8601DateFormatter()

        // Build export dictionaries
        let accountDicts: [[String: Any]] = accounts.map { a in
            [
                "id": "\(a.persistentModelID)",
                "name": a.name,
                "type": a.type.rawValue,
                "isBudget": a.isBudget,
                "sortOrder": a.sortOrder,
                "createdAt": dateFormatter.string(from: a.createdAt)
            ]
        }

        let transactionDicts: [[String: Any]] = transactions.map { t in
            var dict: [String: Any] = [
                "id": "\(t.persistentModelID)",
                "amount": "\(t.amount)",
                "payee": t.payee,
                "memo": t.memo,
                "date": dateFormatter.string(from: t.date),
                "type": t.type.rawValue,
                "isCleared": t.isCleared
            ]
            if let acc = t.account {
                dict["accountName"] = acc.name
            }
            if let cat = t.category {
                dict["categoryName"] = cat.name
                if let parent = cat.parent {
                    dict["categoryParent"] = parent.name
                }
            }
            if let transferTo = t.transferToAccount {
                dict["transferToAccountName"] = transferTo.name
            }
            return dict
        }

        let categoryDicts: [[String: Any]] = categories.map { c in
            var dict: [String: Any] = [
                "id": "\(c.persistentModelID)",
                "name": c.name,
                "emoji": c.emoji,
                "isHeader": c.isHeader,
                "isSystem": c.isSystem,
                "sortOrder": c.sortOrder
            ]
            if let parent = c.parent {
                dict["parentName"] = parent.name
            }
            return dict
        }

        let budgetMonthDicts: [[String: Any]] = budgetMonths.map { bm in
            [
                "id": "\(bm.persistentModelID)",
                "month": dateFormatter.string(from: bm.month),
                "note": bm.note
            ]
        }

        let allocationDicts: [[String: Any]] = allocations.map { a in
            var dict: [String: Any] = [
                "id": "\(a.persistentModelID)",
                "budgeted": "\(a.budgeted)"
            ]
            if let cat = a.category {
                dict["categoryName"] = cat.name
                if let parent = cat.parent {
                    dict["categoryParent"] = parent.name
                }
            }
            if let bm = a.budgetMonth {
                dict["month"] = dateFormatter.string(from: bm.month)
            }
            return dict
        }

        let payeeDicts: [[String: Any]] = payees.map { p in
            var dict: [String: Any] = [
                "name": p.name,
                "lastUsedDate": dateFormatter.string(from: p.lastUsedDate),
                "useCount": p.useCount
            ]
            if let cat = p.lastUsedCategory {
                dict["lastUsedCategoryName"] = cat.name
            }
            return dict
        }

        let exportData: [String: Any] = [
            "exportDate": dateFormatter.string(from: Date()),
            "appVersion": "1.0",
            "accounts": accountDicts,
            "transactions": transactionDicts,
            "categories": categoryDicts,
            "budgetMonths": budgetMonthDicts,
            "budgetAllocations": allocationDicts,
            "payees": payeeDicts
        ]

        return try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys])
    }

    /// Write the export to a temporary file and return its URL.
    static func exportToFile(context: ModelContext) throws -> URL {
        let data = try exportJSON(context: context)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let filename = "FamFin-backup-\(dateFormatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }

    // MARK: - Import

    /// Restore app data from a JSON backup file.
    /// This is a FULL REPLACE — all existing data is deleted first.
    static func importJSON(from url: URL, context: ModelContext) throws {
        // Read and parse JSON
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImportError.invalidFormat
        }

        let dateFormatter = ISO8601DateFormatter()

        // 1. Delete all existing data (order matters for relationships)
        let existingTransactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        for t in existingTransactions { context.delete(t) }

        let existingAllocations = (try? context.fetch(FetchDescriptor<BudgetAllocation>())) ?? []
        for a in existingAllocations { context.delete(a) }

        let existingPayees = (try? context.fetch(FetchDescriptor<Payee>())) ?? []
        for p in existingPayees { context.delete(p) }

        let existingBudgetMonths = (try? context.fetch(FetchDescriptor<BudgetMonth>())) ?? []
        for bm in existingBudgetMonths { context.delete(bm) }

        let existingCategories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        for c in existingCategories { context.delete(c) }

        let existingAccounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        for a in existingAccounts { context.delete(a) }

        try context.save()

        // 2. Import categories (headers first, then subcategories)
        // Uses composite keys "parentName/name" for subcategories to handle duplicate names
        let categoryDicts = json["categories"] as? [[String: Any]] ?? []
        var categoryByKey: [String: Category] = [:]

        // Pass 1: Create header categories and system categories (no parent)
        for dict in categoryDicts {
            guard let name = dict["name"] as? String else { continue }
            let isHeader = dict["isHeader"] as? Bool ?? false
            let isSystem = dict["isSystem"] as? Bool ?? false
            let parentName = dict["parentName"] as? String

            if isHeader || isSystem || parentName == nil {
                let cat = Category(
                    name: name,
                    emoji: dict["emoji"] as? String ?? "📁",
                    isHeader: isHeader,
                    isSystem: isSystem,
                    sortOrder: dict["sortOrder"] as? Int ?? 0
                )
                context.insert(cat)
                categoryByKey[name] = cat
            }
        }

        // Pass 2: Create subcategories (have a parent)
        for dict in categoryDicts {
            guard let name = dict["name"] as? String else { continue }
            let parentName = dict["parentName"] as? String
            let isHeader = dict["isHeader"] as? Bool ?? false
            let isSystem = dict["isSystem"] as? Bool ?? false

            if !isHeader && !isSystem, let parentName = parentName {
                let cat = Category(
                    name: name,
                    emoji: dict["emoji"] as? String ?? "📁",
                    isHeader: false,
                    isSystem: false,
                    sortOrder: dict["sortOrder"] as? Int ?? 0
                )
                cat.parent = categoryByKey[parentName]
                context.insert(cat)
                // Composite key for subcategories to avoid collisions
                categoryByKey["\(parentName)/\(name)"] = cat
                // Store by bare name only if no other category has claimed it,
                // so duplicate names across headers don't overwrite each other
                if categoryByKey[name] == nil {
                    categoryByKey[name] = cat
                }
            }
        }

        // 3. Import accounts
        let accountDicts = json["accounts"] as? [[String: Any]] ?? []
        var accountByName: [String: Account] = [:]

        for dict in accountDicts {
            guard let name = dict["name"] as? String,
                  let typeRaw = dict["type"] as? String else { continue }
            let type = AccountType(rawValue: typeRaw) ?? .current
            let isBudget = dict["isBudget"] as? Bool ?? true
            let sortOrder = dict["sortOrder"] as? Int ?? 0
            let account = Account(name: name, type: type, isBudget: isBudget, sortOrder: sortOrder)
            if let createdStr = dict["createdAt"] as? String,
               let createdAt = dateFormatter.date(from: createdStr) {
                account.createdAt = createdAt
            }
            context.insert(account)
            accountByName[name] = account
        }

        // 4. Import budget months
        let budgetMonthDicts = json["budgetMonths"] as? [[String: Any]] ?? []
        var budgetMonthByDateStr: [String: BudgetMonth] = [:]

        for dict in budgetMonthDicts {
            guard let monthStr = dict["month"] as? String,
                  let monthDate = dateFormatter.date(from: monthStr) else { continue }
            let bm = BudgetMonth(month: monthDate, note: dict["note"] as? String ?? "")
            context.insert(bm)
            budgetMonthByDateStr[monthStr] = bm
        }

        // 5. Import budget allocations
        let allocationDicts = json["budgetAllocations"] as? [[String: Any]] ?? []

        for dict in allocationDicts {
            guard let budgetedStr = dict["budgeted"] as? String,
                  let budgeted = Decimal(string: budgetedStr) else { continue }
            let allocation = BudgetAllocation(budgeted: budgeted)

            // Link to category (use parentName/name composite key to disambiguate)
            if let catName = dict["categoryName"] as? String {
                if let parentName = dict["categoryParent"] as? String {
                    allocation.category = categoryByKey["\(parentName)/\(catName)"] ?? categoryByKey[catName]
                } else {
                    allocation.category = categoryByKey[catName]
                }
            }

            // Link to budget month
            if let monthStr = dict["month"] as? String {
                allocation.budgetMonth = budgetMonthByDateStr[monthStr]
            }

            context.insert(allocation)
        }

        // 6. Import transactions
        let transactionDicts = json["transactions"] as? [[String: Any]] ?? []

        for dict in transactionDicts {
            guard let amountStr = dict["amount"] as? String,
                  let amount = Decimal(string: amountStr),
                  let typeRaw = dict["type"] as? String else { continue }
            let type = TransactionType(rawValue: typeRaw) ?? .expense
            let payee = dict["payee"] as? String ?? ""
            let memo = dict["memo"] as? String ?? ""
            let isCleared = dict["isCleared"] as? Bool ?? false
            var date = Date()
            if let dateStr = dict["date"] as? String,
               let parsedDate = dateFormatter.date(from: dateStr) {
                date = parsedDate
            }

            let transaction = Transaction(
                amount: amount,
                payee: payee,
                memo: memo,
                date: date,
                type: type,
                isCleared: isCleared
            )

            // Link to account
            if let accountName = dict["accountName"] as? String {
                transaction.account = accountByName[accountName]
            }

            // Link to category (use composite key to disambiguate)
            if let catName = dict["categoryName"] as? String {
                if let parentName = dict["categoryParent"] as? String {
                    transaction.category = categoryByKey["\(parentName)/\(catName)"] ?? categoryByKey[catName]
                } else {
                    transaction.category = categoryByKey[catName]
                }
            }

            // Link to transfer destination
            if let transferName = dict["transferToAccountName"] as? String {
                transaction.transferToAccount = accountByName[transferName]
            }

            context.insert(transaction)
        }

        // 7. Import payees
        let payeeDicts = json["payees"] as? [[String: Any]] ?? []

        for dict in payeeDicts {
            guard let name = dict["name"] as? String else { continue }
            let payee = Payee(name: name)
            if let dateStr = dict["lastUsedDate"] as? String,
               let parsedDate = dateFormatter.date(from: dateStr) {
                payee.lastUsedDate = parsedDate
            }
            payee.useCount = dict["useCount"] as? Int ?? 1
            if let catName = dict["lastUsedCategoryName"] as? String {
                payee.lastUsedCategory = categoryByKey[catName]
            }
            context.insert(payee)
        }

        try context.save()
    }

    enum ImportError: LocalizedError {
        case invalidFormat

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "The file is not a valid FamFin backup."
            }
        }
    }
}
