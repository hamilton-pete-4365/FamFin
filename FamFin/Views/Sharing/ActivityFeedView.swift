import SwiftUI
import SwiftData

/// Displays recent activity from all participants in the shared family budget.
///
/// Entries are grouped by date and shown in reverse chronological order,
/// so the most recent actions appear at the top. Each entry shows who
/// performed the action, what they did, and when.
struct ActivityFeedView: View {
    @Query(sort: \ActivityEntry.timestamp, order: .reverse)
    private var allEntries: [ActivityEntry]

    @Environment(\.modelContext) private var modelContext
    @Environment(SharingManager.self) private var sharingManager

    private var groupedEntries: [ActivityGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: allEntries) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { ActivityGroup(date: $0.key, entries: $0.value) }
    }

    var body: some View {
        Group {
            if allEntries.isEmpty {
                ContentUnavailableView(
                    "No Activity Yet",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Activity from family members will appear here when they add transactions or edit budgets.")
                )
            } else {
                List {
                    ForEach(groupedEntries) { group in
                        Section {
                            ForEach(group.entries) { entry in
                                ActivityEntryRow(entry: entry)
                            }
                        } header: {
                            Text(group.date, format: .dateTime.weekday(.wide).day().month(.wide))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Activity Feed")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            sharingManager.markActivityAsRead(context: modelContext)
        }
    }
}

// MARK: - Activity Group

/// Groups activity entries by calendar day for section display.
struct ActivityGroup: Identifiable {
    let date: Date
    let entries: [ActivityEntry]
    var id: Date { date }
}

// MARK: - Activity Entry Row

/// Renders a single activity feed entry with an icon, description, and timestamp.
struct ActivityEntryRow: View {
    let entry: ActivityEntry

    private var iconColor: Color {
        switch entry.activityType {
        case .addedTransaction: return .green
        case .editedTransaction: return .blue
        case .deletedTransaction: return .red
        case .editedBudget: return .orange
        case .joinedFamily: return .green
        case .leftFamily: return .red
        }
    }

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: entry.activityType.systemImage)
                .foregroundStyle(iconColor)
                .font(.title3)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.message)
                    .font(.subheadline)

                HStack(spacing: 4) {
                    Text(entry.participantName)
                        .bold()
                    Text("·")
                    Text(entry.timestamp, format: .dateTime.hour().minute())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.participantName): \(entry.message), \(entry.timestamp, format: .dateTime.hour().minute())")
    }
}

#Preview {
    NavigationStack {
        ActivityFeedView()
    }
    .modelContainer(for: ActivityEntry.self, inMemory: true)
    .environment(SharingManager())
}
