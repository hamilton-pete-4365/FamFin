import SwiftUI

/// Reusable profile icon button placed in the top-left toolbar of every tab.
/// Opens SettingsView as a sheet.
struct ProfileButton: View {
    @State private var showingSettings = false

    var body: some View {
        Button("Settings", systemImage: "person.circle") {
            showingSettings = true
        }
        .accessibilityHint("Double tap to open settings")
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}
