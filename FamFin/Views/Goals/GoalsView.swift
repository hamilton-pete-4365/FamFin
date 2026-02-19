import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    @State private var showingAddGoal = false

    /// Current month normalised to first-of-month for goal calculations
    private var currentMonth: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }

    var body: some View {
        NavigationStack {
            Group {
                if goals.isEmpty {
                    GoalsEmptyStateView()
                } else {
                    GoalsListView(goals: goals, currentMonth: currentMonth)
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileButton()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Goal", systemImage: "plus") {
                        showingAddGoal = true
                    }
                    .accessibilityHint("Double tap to create a new savings goal")
                }
            }
            .sheet(isPresented: $showingAddGoal) {
                AddGoalView()
            }
        }
    }
}

// MARK: - Empty State

struct GoalsEmptyStateView: View {
    var body: some View {
        ContentUnavailableView(
            "No Savings Goals",
            systemImage: "target",
            description: Text("Tap + to create your first savings goal and start tracking your progress.")
        )
    }
}

// MARK: - Goals List

struct GoalsListView: View {
    let goals: [SavingsGoal]
    let currentMonth: Date

    private var activeGoals: [SavingsGoal] {
        goals.filter { !$0.isComplete(through: currentMonth) }
    }

    private var completedGoals: [SavingsGoal] {
        goals.filter { $0.isComplete(through: currentMonth) }
    }

    var body: some View {
        List {
            if !activeGoals.isEmpty {
                Section("In Progress") {
                    ForEach(activeGoals) { goal in
                        NavigationLink(value: goal.persistentModelID) {
                            GoalRowView(goal: goal, currentMonth: currentMonth)
                        }
                    }
                }
            }

            if !completedGoals.isEmpty {
                Section("Completed") {
                    ForEach(completedGoals) { goal in
                        NavigationLink(value: goal.persistentModelID) {
                            GoalRowView(goal: goal, currentMonth: currentMonth)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: PersistentIdentifier.self) { goalID in
            GoalDetailView(goalID: goalID)
        }
    }
}

// MARK: - Goal Row

struct GoalRowView: View {
    let goal: SavingsGoal
    let currentMonth: Date
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    private var goalProgress: Double {
        goal.progress(through: currentMonth)
    }

    private var progressColor: Color {
        if goal.isComplete(through: currentMonth) { return .green }
        if goalProgress >= 0.75 { return .blue }
        if goalProgress >= 0.5 { return .orange }
        return .accentColor
    }

    var body: some View {
        HStack(spacing: 12) {
            // Progress ring with emoji overlay
            ZStack {
                ProgressRingView(progress: goalProgress, color: progressColor, lineWidth: 5)
                    .frame(width: 48, height: 48)

                Text(goal.emoji)
                    .font(.title3)
            }
            .accessibilityHidden(true)

            // Goal details
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.name)
                    .font(.headline)

                HStack(spacing: 4) {
                    Text(formatGBP(goal.currentAmount(through: currentMonth), currencyCode: currencyCode))
                        .foregroundStyle(.secondary)
                    Text("/")
                        .foregroundStyle(.tertiary)
                    Text(formatGBP(goal.targetAmount, currencyCode: currencyCode))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .monospacedDigit()

                GoalRowMetadataView(goal: goal, currentMonth: currentMonth)
            }

            Spacer()

            // Percentage
            Text(goalProgress, format: .percent.precision(.fractionLength(0)))
                .font(.title3.bold())
                .foregroundStyle(progressColor)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to view goal details")
    }

    private var accessibilityDescription: String {
        var parts = ["\(goal.name)", "\(Int(goalProgress * 100)) percent complete"]
        parts.append("\(formatGBP(goal.currentAmount(through: currentMonth), currencyCode: currencyCode)) of \(formatGBP(goal.targetAmount, currencyCode: currencyCode))")
        if let days = goal.daysRemaining {
            if days > 0 {
                parts.append("\(days) days remaining")
            } else if days == 0 {
                parts.append("due today")
            } else {
                parts.append("overdue")
            }
        }
        if goal.isComplete(through: currentMonth) {
            parts.append("completed")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Goal Row Metadata

struct GoalRowMetadataView: View {
    let goal: SavingsGoal
    let currentMonth: Date

    var body: some View {
        HStack(spacing: 8) {
            if let category = goal.linkedCategory {
                Label("\(category.emoji) \(category.name)", systemImage: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let days = goal.daysRemaining {
                if days > 0 {
                    Label("\(days) days left", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if days == 0 {
                    Label("Due today", systemImage: "calendar.badge.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Label("Overdue", systemImage: "calendar.badge.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if goal.isComplete(through: currentMonth) {
                Label("Complete", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }
}

#Preview {
    GoalsView()
        .modelContainer(for: [SavingsGoal.self, Category.self, ActivityEntry.self], inMemory: true)
        .environment(SharingManager())
        .environment(ReviewPromptManager())
}
