import SwiftUI

/// Reusable profile icon button placed in the top-left toolbar of every tab.
/// Opens SettingsView as a sheet. Shows a badge when unread sharing activity exists.
struct ProfileButton: View {
    @Environment(SharingManager.self) private var sharingManager
    @State private var showingSettings = false

    var body: some View {
        Button("Settings", systemImage: "person.circle") {
            showingSettings = true
        }
        .overlay(alignment: .topTrailing) {
            if sharingManager.unreadActivityCount > 0 {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .offset(x: 2, y: -2)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(sharingManager.unreadActivityCount > 0
            ? "Settings, \(sharingManager.unreadActivityCount) unread"
            : "Settings")
        .accessibilityHint("Double tap to open settings")
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}
