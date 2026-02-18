import Foundation
import CloudKit
import SwiftData

/// Manages CKShare creation and participant management for shared family budgets.
///
/// This service wraps CloudKit sharing APIs to enable multiple family members
/// to collaborate on a single budget. It tracks the current sharing state,
/// manages invitations, and handles role-based access (owner vs member).
///
/// The sharing feature is included in Pro and does not require a separate
/// subscription. It relies on the existing iCloud sync infrastructure
/// (Phase 2.1) and uses the shared CloudKit database for collaborative data.
///
/// When iCloud entitlements are unavailable (e.g. free developer account),
/// all sharing operations gracefully no-op and ``isAvailable`` returns false.
@MainActor @Observable
final class SharingManager {

    // MARK: - Sharing state

    /// Whether the budget is currently shared with other people.
    private(set) var isShared = false

    /// The participants in the current share (includes the owner).
    private(set) var participants: [Participant] = []

    /// Whether a sharing operation is in progress.
    private(set) var isProcessing = false

    /// User-facing error from the last operation.
    var sharingError: String?

    /// The display name of the current iCloud user.
    private(set) var currentUserName: String = "You"

    /// The CKShare associated with this budget, if any.
    private(set) var activeShare: CKShare?

    /// Whether CloudKit sharing is available on this device.
    var isAvailable: Bool { container != nil }

    // MARK: - Participant model

    /// A simplified representation of a CKShare participant for the UI.
    struct Participant: Identifiable, Sendable {
        let id: String
        let name: String
        let role: Role
        let acceptanceStatus: CKShare.ParticipantAcceptanceStatus

        enum Role: String, Sendable {
            case owner = "Owner"
            case member = "Member"
        }

        /// Whether this participant has accepted the share invitation.
        var hasAccepted: Bool {
            acceptanceStatus == .accepted
        }

        /// Display-friendly status text.
        var statusText: String {
            switch acceptanceStatus {
            case .accepted: return "Active"
            case .pending: return "Pending"
            case .removed: return "Removed"
            case .unknown: return "Unknown"
            @unknown default: return "Unknown"
            }
        }
    }

    // MARK: - Role helpers

    /// Whether the current user is the owner of the share.
    var isOwner: Bool {
        guard let share = activeShare else { return true }
        return share.currentUserParticipant?.role == .owner
    }

    /// Whether the current user is a member (not owner) of the share.
    var isMember: Bool {
        isShared && !isOwner
    }

    /// Whether the current user can manage participants (only owners).
    var canManageParticipants: Bool {
        isOwner
    }

    // MARK: - Private

    /// The CloudKit container, or nil when iCloud entitlements are unavailable.
    @ObservationIgnored
    private let container: CKContainer?

    // MARK: - Initialisation

    init() {
        // Only create the CKContainer when CloudKit entitlements are present.
        if SharedModelContainer.isCloudKitAvailable {
            container = CKContainer(identifier: "iCloud.com.famfin.app")
        } else {
            container = nil
        }

        if container != nil {
            Task { await refreshSharingState() }
        }
    }

    // MARK: - Public API

    /// Refreshes the sharing state by checking CloudKit for existing shares.
    func refreshSharingState() async {
        guard let container else {
            status_unavailable()
            return
        }

        do {
            // Fetch the current user's record ID for later reference.
            // The display name will be resolved from the share's participant list
            // once a share is active, since direct user identity APIs are deprecated.
            _ = try await container.userRecordID()

            // Check for existing shares in the shared database
            let sharedDB = container.sharedCloudDatabase
            let zones = try await sharedDB.allRecordZones()

            if !zones.isEmpty {
                // We are participating in a share
                isShared = true
                await loadParticipants()
            } else {
                // Check private database for shares we own
                let privateDB = container.privateCloudDatabase
                let privateZones = try await privateDB.allRecordZones()
                var foundShare = false

                for zone in privateZones {
                    let query = CKQuery(
                        recordType: "cloudkit.share",
                        predicate: NSPredicate(value: true)
                    )
                    do {
                        let (results, _) = try await privateDB.records(
                            matching: query,
                            inZoneWith: zone.zoneID,
                            resultsLimit: 1
                        )
                        if let shareResult = results.first {
                            if let record = try? shareResult.1.get(),
                               let share = record as? CKShare {
                                activeShare = share
                                isShared = share.participants.count > 1
                                foundShare = true
                                await loadParticipants()
                                break
                            }
                        }
                    } catch {
                        // Zone may not contain shares; continue checking
                        continue
                    }
                }

                if !foundShare {
                    isShared = false
                    participants = []
                    activeShare = nil
                }
            }
        } catch {
            sharingError = "Unable to check sharing status."
        }
    }

    /// Creates a new CKShare for the family budget.
    /// Returns the share so it can be presented via UICloudSharingController.
    @discardableResult
    func createShare() async throws -> CKShare {
        guard let container else {
            throw SharingError.unavailable
        }

        isProcessing = true
        sharingError = nil
        defer { isProcessing = false }

        let privateDB = container.privateCloudDatabase

        // Create or use the default zone
        let zoneID = CKRecordZone.ID(
            zoneName: "FamFinSharedZone",
            ownerName: CKCurrentUserDefaultName
        )
        let zone = CKRecordZone(zoneID: zoneID)

        do {
            try await privateDB.save(zone)
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Zone may already exist; that is fine
        }

        // Create the share record
        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = "FamFin Family Budget" as CKRecordValue
        share.publicPermission = .readWrite

        try await privateDB.save(share)

        activeShare = share
        isShared = true
        await loadParticipants()

        return share
    }

    /// Adds a participant to the current share by their email lookup.
    func addParticipant(emailAddress: String) async {
        guard let container else { return }
        guard let share = activeShare else {
            sharingError = "No active share found. Create a share first."
            return
        }

        isProcessing = true
        sharingError = nil
        defer { isProcessing = false }

        do {
            let lookupInfo = CKUserIdentity.LookupInfo(emailAddress: emailAddress)
            let results = try await container.shareParticipants(for: [lookupInfo])

            guard let result = results[lookupInfo],
                  let participant = try? result.get() else {
                sharingError = "Could not find an iCloud user with that email address."
                return
            }

            participant.permission = .readWrite
            share.addParticipant(participant)

            try await container.privateCloudDatabase.save(share)
            await loadParticipants()
        } catch {
            sharingError = "Failed to add participant: \(error.localizedDescription)"
        }
    }

    /// Removes a participant from the current share. Only the owner can do this.
    func removeParticipant(_ participant: Participant) async {
        guard let container else { return }
        guard isOwner else {
            sharingError = "Only the share owner can remove participants."
            return
        }
        guard let share = activeShare else { return }

        isProcessing = true
        sharingError = nil
        defer { isProcessing = false }

        do {
            if let ckParticipant = share.participants.first(where: {
                participantID(for: $0) == participant.id
            }) {
                share.removeParticipant(ckParticipant)
                try await container.privateCloudDatabase.save(share)
                await loadParticipants()
            }
        } catch {
            sharingError = "Failed to remove participant: \(error.localizedDescription)"
        }
    }

    /// Leaves the current share. For members only (owners should delete the share).
    func leaveShare() async {
        guard let container else { return }

        isProcessing = true
        sharingError = nil
        defer { isProcessing = false }

        do {
            if isOwner {
                // Owner deleting the share
                if let share = activeShare {
                    try await container.privateCloudDatabase.deleteRecord(withID: share.recordID)
                }
            } else {
                // Member leaving: remove all shared zones
                let sharedDB = container.sharedCloudDatabase
                let zones = try await sharedDB.allRecordZones()
                for zone in zones {
                    try await sharedDB.deleteRecordZone(withID: zone.zoneID)
                }
            }

            activeShare = nil
            isShared = false
            participants = []
        } catch {
            sharingError = "Failed to leave share: \(error.localizedDescription)"
        }
    }

    // MARK: - Activity logging

    /// Logs an activity entry to the SwiftData store.
    func logActivity(
        message: String,
        type: ActivityType,
        context: ModelContext
    ) {
        let entry = ActivityEntry(
            message: message,
            participantName: currentUserName,
            activityType: type
        )
        context.insert(entry)
    }

    // MARK: - Error types

    enum SharingError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "iCloud sharing is not available. A paid Apple Developer account with iCloud entitlements is required."
            }
        }
    }

    // MARK: - Private helpers

    /// Sets state for when CloudKit is not available.
    private func status_unavailable() {
        isShared = false
        participants = []
        activeShare = nil
    }

    /// Reloads the participant list from the active share.
    /// Also resolves the current user's display name from the share's participant data.
    private func loadParticipants() async {
        guard let share = activeShare else {
            participants = []
            return
        }

        let formatter = PersonNameComponentsFormatter()
        var loaded: [Participant] = []

        for ckParticipant in share.participants {
            let name: String
            if let components = ckParticipant.userIdentity.nameComponents {
                name = formatter.string(from: components)
            } else {
                name = ckParticipant.userIdentity.lookupInfo?.emailAddress ?? "Unknown"
            }

            let role: Participant.Role = ckParticipant.role == .owner ? .owner : .member
            loaded.append(Participant(
                id: participantID(for: ckParticipant),
                name: name,
                role: role,
                acceptanceStatus: ckParticipant.acceptanceStatus
            ))

            // Update current user's display name from the share data
            if ckParticipant == share.currentUserParticipant, !name.isEmpty, name != "Unknown" {
                currentUserName = name
            }
        }

        // Sort so owner is first, then by name
        loaded.sort { lhs, rhs in
            if lhs.role == .owner && rhs.role != .owner { return true }
            if lhs.role != .owner && rhs.role == .owner { return false }
            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }

        participants = loaded
    }

    /// Generates a stable identifier for a CKShare.Participant.
    private func participantID(for participant: CKShare.Participant) -> String {
        participant.userIdentity.lookupInfo?.emailAddress
            ?? participant.userIdentity.userRecordID?.recordName
            ?? UUID().uuidString
    }
}
