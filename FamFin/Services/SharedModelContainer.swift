import Foundation
import SwiftData

/// Provides a shared ModelContainer configuration that both the main app and widget extension
/// can use to access the same SwiftData store via an App Group container.
enum SharedModelContainer {

    /// The App Group identifier shared between the main app and widget extension.
    static let appGroupIdentifier = "group.com.famfin.app"

    /// The shared schema used by both the app and widget.
    static let schema = Schema([
        Account.self,
        Transaction.self,
        Category.self,
        BudgetMonth.self,
        BudgetAllocation.self,
        Payee.self,
        RecurringTransaction.self,
        ActivityEntry.self
    ])

    /// URL for the shared SwiftData store inside the App Group container.
    /// Returns nil if the App Group container is unavailable.
    static var storeURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appending(path: "FamFin.store")
    }

    /// Whether iCloud entitlements are available at runtime.
    /// When false, CloudKit sync is disabled and the store falls back to local-only.
    static var isCloudKitAvailable: Bool {
        storeURL != nil
    }

    /// Creates a ModelContainer pointing to the shared App Group container.
    /// Uses CloudKit when entitlements are present, otherwise falls back to local-only storage.
    static func makeAppContainer() throws -> ModelContainer {
        let url = storeURL ?? URL.documentsDirectory.appending(path: "FamFin.store")
        let cloudKit: ModelConfiguration.CloudKitDatabase = isCloudKitAvailable ? .automatic : .none

        let configuration = ModelConfiguration(
            "FamFin",
            schema: schema,
            url: url,
            cloudKitDatabase: cloudKit
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }

    /// Creates a ModelContainer for the widget extension.
    /// Widgets use a read-only connection without CloudKit sync.
    static func makeWidgetContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "FamFin",
            schema: schema,
            url: storeURL ?? URL.documentsDirectory.appending(path: "FamFin.store"),
            cloudKitDatabase: .none
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}
