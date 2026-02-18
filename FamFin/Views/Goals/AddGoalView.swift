import SwiftUI
import SwiftData

struct AddGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SharingManager.self) private var sharingManager
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    @State private var name: String = ""
    @State private var emoji: String = "🎯"
    @State private var targetAmountText: String = ""
    @State private var hasTargetDate = false
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var selectedCategory: Category?

    private var subcategories: [Category] {
        allCategories.filter { !$0.isHeader && !$0.isSystem }
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
                        .accessibilityLabel("Goal name")

                    TextField("Emoji", text: $emoji)
                        .accessibilityLabel("Goal emoji")
                        .accessibilityHint("Enter a single emoji for this goal")
                        .onChange(of: emoji) { _, newValue in
                            if newValue.count > 1 {
                                emoji = String(newValue.prefix(1))
                            }
                        }

                    TextField("Target Amount", text: $targetAmountText)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Target amount")
                        .accessibilityHint("Enter the total amount you want to save")
                }

                Section("Target Date") {
                    Toggle("Set Target Date", isOn: $hasTargetDate)
                        .accessibilityHint("Enable to set a deadline for reaching this goal")

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
                    .accessibilityLabel("Linked budget category")
                } header: {
                    Text("Budget Category")
                } footer: {
                    Text("Link this goal to a budget category. Progress is tracked by the category's available balance.")
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveGoal() }
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
    }

    private func saveGoal() {
        guard let targetAmount = Decimal(string: targetAmountText) else { return }

        let goal = SavingsGoal(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            targetAmount: targetAmount,
            targetDate: hasTargetDate ? targetDate : nil,
            emoji: emoji.isEmpty ? "🎯" : emoji
        )

        goal.linkedCategory = selectedCategory

        modelContext.insert(goal)

        // Log activity for shared budgets
        if sharingManager.isShared {
            let message = "\(sharingManager.currentUserName) created a new goal: \(goal.name)"
            sharingManager.logActivity(
                message: message,
                type: .createdGoal,
                context: modelContext
            )
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddGoalView()
        .modelContainer(for: [SavingsGoal.self, Category.self, ActivityEntry.self], inMemory: true)
        .environment(SharingManager())
}
