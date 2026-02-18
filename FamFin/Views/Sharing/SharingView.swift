import SwiftUI
import SwiftData
import CloudKit

/// Main sharing management screen for family budget collaboration.
///
/// Shows the current sharing status, allows creating or managing a share,
/// displays participants with their roles, and provides options to
/// invite new members or leave the share.
struct SharingView: View {
    @Environment(SharingManager.self) private var sharingManager
    @Environment(\.modelContext) private var modelContext

    @State private var showingShareSheet = false
    @State private var showingInviteField = false
    @State private var inviteEmail = ""
    @State private var showingLeaveConfirm = false
    @State private var showingStopSharingConfirm = false
    @State private var showingRemoveConfirm = false
    @State private var participantToRemove: SharingManager.Participant?

    var body: some View {
        List {
            sharingStatusSection

            if sharingManager.isShared {
                participantsSection
                activitySection
                dangerZoneSection
            }
        }
        .navigationTitle("Family Sharing")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await sharingManager.refreshSharingState()
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { sharingManager.sharingError != nil },
                set: { if !$0 { sharingManager.sharingError = nil } }
            )
        ) {
            Button("OK") { sharingManager.sharingError = nil }
        } message: {
            Text(sharingManager.sharingError ?? "")
        }
        .alert("Stop Sharing?", isPresented: $showingStopSharingConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Stop Sharing", role: .destructive) {
                Task {
                    await sharingManager.leaveShare()
                    sharingManager.logActivity(
                        message: "\(sharingManager.currentUserName) stopped sharing the family budget",
                        type: .leftFamily,
                        context: modelContext
                    )
                }
            }
        } message: {
            Text("This will remove all participants and stop sharing your budget. Other family members will lose access to shared data.")
        }
        .alert("Leave Family Budget?", isPresented: $showingLeaveConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) {
                Task {
                    sharingManager.logActivity(
                        message: "\(sharingManager.currentUserName) left the family budget",
                        type: .leftFamily,
                        context: modelContext
                    )
                    await sharingManager.leaveShare()
                }
            }
        } message: {
            Text("You will lose access to the shared family budget data. You can rejoin if invited again.")
        }
        .alert(
            "Remove \(participantToRemove?.name ?? "Participant")?",
            isPresented: $showingRemoveConfirm
        ) {
            Button("Cancel", role: .cancel) { participantToRemove = nil }
            Button("Remove", role: .destructive) {
                if let participant = participantToRemove {
                    Task {
                        sharingManager.logActivity(
                            message: "\(sharingManager.currentUserName) removed \(participant.name) from the family budget",
                            type: .leftFamily,
                            context: modelContext
                        )
                        await sharingManager.removeParticipant(participant)
                    }
                }
                participantToRemove = nil
            }
        } message: {
            Text("This person will lose access to the shared family budget.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var sharingStatusSection: some View {
        Section {
            if sharingManager.isShared {
                Label {
                    VStack(alignment: .leading) {
                        Text("Family Budget Active")
                            .font(.headline)
                        Text("\(sharingManager.participants.count) participant\(sharingManager.participants.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "person.2.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                }
            } else {
                Label {
                    VStack(alignment: .leading) {
                        Text("Not Shared")
                            .font(.headline)
                        Text("Share your budget with family members to collaborate together.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "person.2.slash")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
            }

            if !sharingManager.isShared {
                Button("Start Sharing", systemImage: "square.and.arrow.up") {
                    Task {
                        do {
                            try await sharingManager.createShare()
                            showingShareSheet = true
                        } catch {
                            sharingManager.sharingError = "Failed to create share: \(error.localizedDescription)"
                        }
                    }
                }
                .disabled(sharingManager.isProcessing)
            }
        } header: {
            Text("Sharing Status")
        } footer: {
            if !sharingManager.isShared {
                Text("Sharing lets family members add transactions, view the budget, and track goals together. All data syncs in real-time via iCloud.")
            }
        }
    }

    @ViewBuilder
    private var participantsSection: some View {
        Section {
            ForEach(sharingManager.participants) { participant in
                ParticipantRow(
                    participant: participant,
                    isCurrentUser: participant.name == sharingManager.currentUserName,
                    canRemove: sharingManager.isOwner && participant.role != .owner,
                    onRemove: {
                        participantToRemove = participant
                        showingRemoveConfirm = true
                    }
                )
            }

            if sharingManager.isOwner {
                if showingInviteField {
                    HStack {
                        TextField("Email address", text: $inviteEmail)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Button("Invite", systemImage: "paperplane.fill") {
                            Task {
                                await sharingManager.addParticipant(emailAddress: inviteEmail)
                                inviteEmail = ""
                                showingInviteField = false
                            }
                        }
                        .disabled(inviteEmail.isEmpty || sharingManager.isProcessing)
                    }
                } else {
                    Button("Invite Family Member", systemImage: "person.badge.plus") {
                        showingInviteField = true
                    }
                }
            }
        } header: {
            Text("Participants")
        } footer: {
            if sharingManager.isOwner {
                Text("As the owner, you have full control. Members can add transactions and view the budget.")
            } else {
                Text("You can add transactions and view the shared budget. The owner manages participants.")
            }
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        Section {
            NavigationLink {
                ActivityFeedView()
            } label: {
                Label("Activity Feed", systemImage: "list.bullet.clipboard")
            }
        } header: {
            Text("Activity")
        } footer: {
            Text("See recent actions by all family members.")
        }
    }

    @ViewBuilder
    private var dangerZoneSection: some View {
        Section {
            if sharingManager.isOwner {
                Button(role: .destructive) {
                    showingStopSharingConfirm = true
                } label: {
                    Label("Stop Sharing", systemImage: "xmark.circle")
                }
            } else {
                Button(role: .destructive) {
                    showingLeaveConfirm = true
                } label: {
                    Label("Leave Family Budget", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
    }
}

// MARK: - Participant Row

/// Displays a single participant with their name, role badge, and status.
struct ParticipantRow: View {
    let participant: SharingManager.Participant
    let isCurrentUser: Bool
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Image(systemName: participant.role == .owner ? "crown.fill" : "person.fill")
                .foregroundStyle(participant.role == .owner ? .orange : .accentColor)
                .font(.title3)

            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(participant.name)
                        .font(.headline)
                    if isCurrentUser {
                        Text("(You)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Text(participant.role.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(participant.role == .owner ? Color.orange.opacity(0.15) : Color.accentColor.opacity(0.15))
                        .clipShape(.capsule)

                    if !participant.hasAccepted {
                        Text(participant.statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if canRemove {
                Button("Remove", systemImage: "minus.circle.fill", role: .destructive) {
                    onRemove()
                }
                .labelStyle(.iconOnly)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = [participant.name]
        if isCurrentUser { parts.append("you") }
        parts.append(participant.role.rawValue)
        if !participant.hasAccepted { parts.append(participant.statusText) }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    NavigationStack {
        SharingView()
    }
    .environment(SharingManager())
    .modelContainer(for: ActivityEntry.self, inMemory: true)
}
