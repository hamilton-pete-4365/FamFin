import Foundation
import CloudKit

/// Tracks iCloud sync status for display in Settings.
///
/// SwiftData with CloudKit handles synchronisation automatically.
/// This manager simply monitors account availability so the UI
/// can show whether sync is active and when data was last refreshed.
///
/// When iCloud entitlements are unavailable (e.g. free developer account),
/// the status is set to ``SyncStatus/unavailable(reason:)`` immediately
/// and no CloudKit calls are made.
@MainActor @Observable
final class SyncManager {

    // MARK: - Sync status

    enum SyncStatus: Equatable {
        case available
        case unavailable(reason: String)
        case checking
    }

    /// Current iCloud availability status.
    private(set) var status: SyncStatus = .checking

    /// Timestamp of the last successful sync check.
    private(set) var lastSyncDate: Date?

    /// Whether a manual refresh is in progress.
    private(set) var isRefreshing = false

    // MARK: - Private

    private static let lastSyncDateKey = "com.famfin.lastSyncDate"

    // MARK: - Initialisation

    init() {
        // Restore persisted last-sync date.
        lastSyncDate = UserDefaults.standard.object(forKey: Self.lastSyncDateKey) as? Date

        // Only check iCloud when entitlements are present.
        if SharedModelContainer.isCloudKitAvailable {
            Task { await checkAccountStatus() }
        } else {
            status = .unavailable(reason: "iCloud sync requires a paid developer account with iCloud entitlements.")
        }
    }

    // MARK: - Public API

    /// Checks the iCloud account status and records a sync timestamp
    /// if the account is available. This does not force a CloudKit push
    /// or pull -- SwiftData handles that automatically -- but it gives
    /// the user confidence that sync is operational.
    func refreshSync() async {
        guard SharedModelContainer.isCloudKitAvailable else { return }

        isRefreshing = true
        defer { isRefreshing = false }
        await checkAccountStatus()
    }

    // MARK: - Helpers

    /// Display-friendly description of the current status.
    var statusDescription: String {
        switch status {
        case .available:
            return "iCloud Sync Active"
        case .unavailable(let reason):
            return reason
        case .checking:
            return "Checking iCloud..."
        }
    }

    /// Whether sync is currently enabled and the account is reachable.
    var isSyncEnabled: Bool {
        status == .available
    }

    // MARK: - Private helpers

    private func checkAccountStatus() async {
        status = .checking

        do {
            let accountStatus = try await CKContainer.default().accountStatus()
            switch accountStatus {
            case .available:
                status = .available
                let now = Date.now
                lastSyncDate = now
                UserDefaults.standard.set(now, forKey: Self.lastSyncDateKey)

            case .noAccount:
                status = .unavailable(reason: "No iCloud account. Sign in to iCloud in Settings to enable sync.")

            case .restricted:
                status = .unavailable(reason: "iCloud access is restricted on this device.")

            case .couldNotDetermine:
                status = .unavailable(reason: "Unable to determine iCloud status. Please try again later.")

            case .temporarilyUnavailable:
                status = .unavailable(reason: "iCloud is temporarily unavailable. Please try again later.")

            @unknown default:
                status = .unavailable(reason: "Unknown iCloud status.")
            }
        } catch {
            status = .unavailable(reason: "Could not reach iCloud. Check your internet connection.")
        }
    }
}
