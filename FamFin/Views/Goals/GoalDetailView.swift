import SwiftUI
import SwiftData

/// Detail view for a savings goal, looked up by its persistent identifier.
struct GoalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    let goalID: PersistentIdentifier
    @State private var goal: SavingsGoal?
    @State private var showingEdit = false
    @State private var showingDeleteConfirmation = false

    /// Current month normalised to first-of-month for goal calculations
    private var currentMonth: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }

    var body: some View {
        Group {
            if let goal {
                GoalDetailContentView(
                    goal: goal,
                    currentMonth: currentMonth
                )
            } else {
                ContentUnavailableView(
                    "Goal Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This goal may have been deleted.")
                )
            }
        }
        .navigationTitle(goal?.name ?? "Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if goal != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu("Options", systemImage: "ellipsis.circle") {
                        Button("Edit Goal", systemImage: "pencil") {
                            showingEdit = true
                        }
                        Button("Delete Goal", systemImage: "trash", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                    .accessibilityLabel("Goal options")
                    .accessibilityHint("Double tap for edit and delete options")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let goal {
                EditGoalView(goal: goal)
            }
        }
        .alert("Delete Goal?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteGoal()
            }
        } message: {
            Text("This will permanently delete this savings goal. This cannot be undone.")
        }
        .navigationDestination(for: Category.self) { category in
            CategoryDetailView(category: category, month: currentMonth)
        }
        .onAppear { loadGoal() }
    }

    private func loadGoal() {
        goal = modelContext.model(for: goalID) as? SavingsGoal
    }

    private func deleteGoal() {
        if let goal {
            modelContext.delete(goal)
            try? modelContext.save()
        }
        dismiss()
    }
}

// MARK: - Detail Content

struct GoalDetailContentView: View {
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
        ScrollView {
            VStack(spacing: 24) {
                GoalDetailHeaderView(goal: goal, currentMonth: currentMonth, progressColor: progressColor)
                GoalDetailStatsView(goal: goal, currentMonth: currentMonth)
                GoalDetailTimelineView(goal: goal, currentMonth: currentMonth)

                if let linkedCategory = goal.linkedCategory {
                    GoalDetailLinkedCategoryView(category: linkedCategory, currentMonth: currentMonth)
                }
            }
            .padding()
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Header with Progress Ring

struct GoalDetailHeaderView: View {
    let goal: SavingsGoal
    let currentMonth: Date
    let progressColor: Color
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    private var goalProgress: Double {
        goal.progress(through: currentMonth)
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                ProgressRingView(progress: goalProgress, color: progressColor, lineWidth: 12)
                    .frame(width: 160, height: 160)

                VStack(spacing: 4) {
                    Text(goal.emoji)
                        .font(.largeTitle)
                    Text(goalProgress, format: .percent.precision(.fractionLength(0)))
                        .font(.title2.bold())
                        .foregroundStyle(progressColor)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(goal.name), \(Int(goalProgress * 100)) percent complete")

            if goal.isComplete(through: currentMonth) {
                Label("Goal Complete!", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Stats Grid

struct GoalDetailStatsView: View {
    let goal: SavingsGoal
    let currentMonth: Date
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            GoalStatCard(
                title: "Saved",
                value: formatGBP(goal.currentAmount(through: currentMonth), currencyCode: currencyCode),
                icon: "banknote.fill",
                color: .green
            )

            GoalStatCard(
                title: "Target",
                value: formatGBP(goal.targetAmount, currencyCode: currencyCode),
                icon: "flag.fill",
                color: .blue
            )

            GoalStatCard(
                title: "Remaining",
                value: formatGBP(goal.remainingAmount(through: currentMonth), currencyCode: currencyCode),
                icon: "arrow.right.circle.fill",
                color: goal.isComplete(through: currentMonth) ? .green : .orange
            )

            if let monthlyTarget = goal.monthlyTarget(through: currentMonth) {
                GoalStatCard(
                    title: "Monthly Needed",
                    value: formatGBP(monthlyTarget, currencyCode: currencyCode),
                    icon: "calendar.badge.clock",
                    color: .purple
                )
            }
        }
    }
}

/// A single stat card for the stats grid
struct GoalStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .accessibilityHidden(true)

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Timeline

struct GoalDetailTimelineView: View {
    let goal: SavingsGoal
    let currentMonth: Date

    var body: some View {
        if goal.targetDate != nil || goal.projectedCompletionDate(through: currentMonth) != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("Timeline")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: 8) {
                    if let targetDate = goal.targetDate {
                        HStack {
                            Label("Target Date", systemImage: "calendar")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(targetDate, format: .dateTime.day().month(.wide).year())
                        }
                        .font(.subheadline)
                        .accessibilityElement(children: .combine)
                    }

                    if let days = goal.daysRemaining {
                        HStack {
                            Label("Days Remaining", systemImage: "clock")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(daysRemainingText(days))
                                .foregroundStyle(days < 0 ? .red : (days == 0 ? .orange : .primary))
                        }
                        .font(.subheadline)
                        .accessibilityElement(children: .combine)
                    }

                    if let projected = goal.projectedCompletionDate(through: currentMonth) {
                        HStack {
                            Label("Projected", systemImage: "chart.line.uptrend.xyaxis")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(projected, format: .dateTime.month(.wide).year())
                        }
                        .font(.subheadline)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }

    private func daysRemainingText(_ days: Int) -> String {
        if days > 0 {
            return "\(days) days"
        } else if days == 0 {
            return "Today"
        } else {
            return "\(-days) days overdue"
        }
    }
}

// MARK: - Linked Category

struct GoalDetailLinkedCategoryView: View {
    let category: Category
    let currentMonth: Date
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    private var available: Decimal { category.available(through: currentMonth) }

    /// Monthly target needed to keep goal on track
    private var monthlyTarget: Decimal? {
        // If linked goals exist, use the first goal's monthly target
        let goals = category.goals
        return goals.first?.monthlyTarget(through: currentMonth)
    }

    /// Whether the category is underfunded relative to the monthly target
    private var isUnderfunded: Bool {
        guard let target = monthlyTarget else { return false }
        return category.budgeted(in: currentMonth) < target
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Linked Category")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            NavigationLink(value: category) {
                VStack(spacing: 8) {
                    HStack {
                        Text(category.emoji)
                            .font(.title3)
                        Text(category.name)
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }

                    Divider()

                    HStack(spacing: 0) {
                        VStack(spacing: 2) {
                            Text(formatGBP(category.budgeted(in: currentMonth), currencyCode: currencyCode))
                                .font(.subheadline.bold())
                                .monospacedDigit()
                            Text("Budgeted")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 2) {
                            Text(formatGBP(category.activity(in: currentMonth), currencyCode: currencyCode))
                                .font(.subheadline.bold())
                                .monospacedDigit()
                            Text("Activity")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 2) {
                            Text(formatGBP(available, currencyCode: currencyCode))
                                .font(.subheadline.bold())
                                .monospacedDigit()
                                .foregroundStyle(available < 0 ? .red : .primary)
                            Text("Available")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Underfunded warning
                    if isUnderfunded, let target = monthlyTarget {
                        let needed = target - category.budgeted(in: currentMonth)
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Needs \(formatGBP(needed, currencyCode: currencyCode)) more to stay on track")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Linked to category: \(category.name), tap to view details")
        }
    }
}

// MARK: - Edit Goal View

struct EditGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    let goal: SavingsGoal

    @State private var name: String = ""
    @State private var emoji: String = ""
    @State private var targetAmountText: String = ""
    @State private var hasTargetDate = false
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var selectedCategory: Category?
    @State private var hasLoaded = false

    /// Visible subcategories; includes the goal's current category even if hidden
    private var subcategories: [Category] {
        var visible = allCategories.filter { !$0.isHeader && !$0.isSystem && !$0.isHidden }
        if let current = goal.linkedCategory, current.isHidden,
           !visible.contains(where: { $0.persistentModelID == current.persistentModelID }) {
            visible.append(current)
        }
        return visible
    }

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard let amount = Decimal(string: targetAmountText), amount > 0 else { return false }
        return selectedCategory != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Details") {
                    TextField("Goal Name", text: $name)
                    TextField("Emoji", text: $emoji)
                        .onChange(of: emoji) { _, newValue in
                            if newValue.count > 1 {
                                emoji = String(newValue.prefix(1))
                            }
                        }
                    TextField("Target Amount", text: $targetAmountText)
                        .keyboardType(.decimalPad)
                }

                Section("Target Date") {
                    Toggle("Set Target Date", isOn: $hasTargetDate)
                    if hasTargetDate {
                        DatePicker(
                            "Target Date",
                            selection: $targetDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                    }
                }

                Section {
                    Picker("Linked Category", selection: $selectedCategory) {
                        Text("None").tag(Category?.none)
                        ForEach(subcategories) { cat in
                            Text("\(cat.emoji) \(cat.name)")
                                .tag(Category?.some(cat))
                        }
                    }
                } header: {
                    Text("Budget Category")
                } footer: {
                    Text("Link this goal to a budget category. Progress is tracked by the category's available balance.")
                }
            }
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .onAppear {
                guard !hasLoaded else { return }
                hasLoaded = true
                name = goal.name
                emoji = goal.emoji
                targetAmountText = "\(goal.targetAmount)"
                hasTargetDate = goal.targetDate != nil
                if let date = goal.targetDate {
                    targetDate = date
                }
                selectedCategory = goal.linkedCategory
            }
        }
    }

    private func saveChanges() {
        guard let amount = Decimal(string: targetAmountText) else { return }

        goal.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        goal.emoji = emoji.isEmpty ? "🎯" : emoji
        goal.targetAmount = amount
        goal.targetDate = hasTargetDate ? targetDate : nil
        goal.linkedCategory = selectedCategory

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        GoalDetailView(goalID: SavingsGoal(name: "Preview", targetAmount: 1000).persistentModelID)
    }
    .modelContainer(for: [SavingsGoal.self, Category.self, ActivityEntry.self], inMemory: true)
    .environment(SharingManager())
    .environment(ReviewPromptManager())
}
