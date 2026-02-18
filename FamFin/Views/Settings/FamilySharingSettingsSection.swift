import SwiftUI

/// Displays the Family Sharing section in Settings, providing a summary
/// of the sharing status and a navigation link to the full sharing management view.
struct FamilySharingSettingsSection: View {
    @Environment(SharingManager.self) private var sharingManager

    var body: some View {
        Section {
            NavigationLink {
                SharingView()
            } label: {
                Label {
                    VStack(alignment: .leading) {
                        Text("Family Sharing")
                        if sharingManager.isShared {
                            Text("\(sharingManager.participants.count) participant\(sharingManager.participants.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not shared")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: sharingManager.isShared ? "person.2.fill" : "person.2")
                        .foregroundStyle(sharingManager.isShared ? .green : .secondary)
                }
            }
        } header: {
            Text("Family")
        } footer: {
            Text("Share your budget with family members to track spending together.")
        }
    }
}
