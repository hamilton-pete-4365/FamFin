import Foundation
import SwiftData

/// Remembers payees and their most likely category, learned from past transactions.
/// When you type a payee name, we suggest the category that was most recently used for that payee.
@Model
final class Payee {
    var name: String
    @Relationship(deleteRule: .nullify)
    var lastUsedCategory: Category?
    var lastUsedDate: Date
    var useCount: Int

    init(name: String, lastUsedCategory: Category? = nil) {
        self.name = name
        self.lastUsedCategory = lastUsedCategory
        self.lastUsedDate = Date()
        self.useCount = 1
    }

    /// Call this when a transaction is saved with this payee
    func recordUsage(category: Category?) {
        if let category = category {
            lastUsedCategory = category
        }
        lastUsedDate = Date()
        useCount += 1
    }
}
