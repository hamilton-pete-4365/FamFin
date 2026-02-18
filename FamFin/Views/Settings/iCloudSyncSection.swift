import SwiftUI

/// Displays iCloud sync status and a manual refresh button inside a Form.
struct iCloudSyncSection: View {
    @Environment(SyncManager.self) private var syncManager

    var body: some View {
        Section {
            HStack {
                Label {
                    Text(syncManager.statusDescription)
                } icon: {
                    SyncStatusIcon(status: syncManager.status)
                }

                Spacer()

                if syncManager.status == .checking {
                    ProgressView()
                }
            }

            if let lastSync = syncManager.lastSyncDate {
                HStack {
                    Text("Last Synced")
                    Spacer()
                    Text(lastSync, format: .relative(presentation: .named))
                        .foregroundStyle(.secondary)
                }
            }

            Button("Sync Now", systemImage: "arrow.triangle.2.circlepath") {
                Task { await syncManager.refreshSync() }
            }
            .disabled(syncManager.isRefreshing)
        } header: {
            Text("iCloud Sync")
        } footer: {
            Text("Your data syncs automatically across all your devices signed into the same iCloud account.")
        }
    }
}

/// Icon that reflects the current iCloud sync status.
struct SyncStatusIcon: View {
    let status: SyncManager.SyncStatus

    var body: some View {
        switch status {
        case .available:
            Image(systemName: "checkmark.icloud")
                .foregroundStyle(.green)
        case .unavailable:
            Image(systemName: "xmark.icloud")
                .foregroundStyle(.red)
        case .checking:
            Image(systemName: "icloud")
                .foregroundStyle(.secondary)
        }
    }
}
