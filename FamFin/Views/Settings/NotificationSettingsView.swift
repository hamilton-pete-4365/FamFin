import SwiftUI

/// Settings screen for managing budget notification preferences.
/// Permission is requested contextually when the user enables their first toggle.
struct NotificationSettingsView: View {
    @Environment(NotificationManager.self) private var notificationManager

    var body: some View {
        @Bindable var manager = notificationManager

        Form {
            PermissionStatusSection(status: notificationManager.authorizationStatus)

            Section {
                Toggle("Category Budget Alerts", isOn: $manager.categoryAlertEnabled)
                    .onChange(of: manager.categoryAlertEnabled, initial: false) {
                        if manager.categoryAlertEnabled {
                            requestPermissionIfNeeded()
                        }
                    }

                if notificationManager.categoryAlertEnabled {
                    ThresholdSlider(threshold: $manager.categoryThreshold)
                }
            } header: {
                Text("Budget Alerts")
            } footer: {
                Text("Get notified when a category reaches the threshold percentage of its monthly budget, and again when it exceeds 100%.")
            }

            Section {
                Toggle("Weekly Spending Summary", isOn: $manager.weeklyDigestEnabled)
                    .onChange(of: manager.weeklyDigestEnabled, initial: false) {
                        if manager.weeklyDigestEnabled {
                            requestPermissionIfNeeded()
                        }
                    }
            } header: {
                Text("Weekly Digest")
            } footer: {
                Text("Receive a summary of your spending every Sunday evening, including your top spending categories.")
            }

            Section {
                Toggle("Month-End Review Reminder", isOn: $manager.monthEndReminderEnabled)
                    .onChange(of: manager.monthEndReminderEnabled, initial: false) {
                        if manager.monthEndReminderEnabled {
                            requestPermissionIfNeeded()
                        }
                    }
            } header: {
                Text("Month-End Reminder")
            } footer: {
                Text("Get a reminder on the 28th of each month to review your budget before the new month begins.")
            }

            Section {
                Button("Send Test Notification", systemImage: "bell.badge") {
                    notificationManager.sendTestNotification()
                }
                .disabled(notificationManager.authorizationStatus != .authorized)
            } footer: {
                if notificationManager.authorizationStatus != .authorized {
                    Text("Enable notifications to send a test.")
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notificationManager.refreshAuthorizationStatus()
        }
    }

    private func requestPermissionIfNeeded() {
        Task {
            if notificationManager.authorizationStatus == .notDetermined {
                await notificationManager.requestPermission()
            }
        }
    }
}

// MARK: - Permission status section

/// Displays the current notification permission status.
/// If denied, provides guidance to open System Settings.
private struct PermissionStatusSection: View {
    let status: UNAuthorizationStatus

    var body: some View {
        switch status {
        case .denied:
            Section {
                Label {
                    VStack(alignment: .leading) {
                        Text("Notifications Disabled")
                            .bold()
                        Text("Enable notifications in Settings to receive budget alerts.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "bell.slash.fill")
                        .foregroundStyle(.red)
                }

                Button("Open Settings", systemImage: "gear") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        case .authorized, .provisional, .ephemeral:
            EmptyView()
        default:
            EmptyView()
        }
    }
}

// MARK: - Threshold slider

/// A slider that lets the user pick the category alert threshold between 50% and 100%.
private struct ThresholdSlider: View {
    @Binding var threshold: Double

    var body: some View {
        VStack(alignment: .leading) {
            Text("Alert at \(Int(threshold * 100))% spent")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Slider(value: $threshold, in: 0.5...1.0, step: 0.05) {
                Text("Threshold")
            } minimumValueLabel: {
                Text("50%")
                    .font(.caption2)
            } maximumValueLabel: {
                Text("100%")
                    .font(.caption2)
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
            .environment(NotificationManager())
    }
}
