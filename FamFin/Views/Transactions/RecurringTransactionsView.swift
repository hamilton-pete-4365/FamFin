import SwiftUI
import SwiftData

// MARK: - Recurring Transactions List

struct RecurringTransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringTransaction.nextOccurrence) private var allRecurring: [RecurringTransaction]

    @State private var showingAddRecurring = false
    @State private var editingRecurring: RecurringTransaction?

    /// Active rules grouped by frequency
    var activeByFrequency: [RecurrenceFrequencyGroup] {
        let active = allRecurring.filter { $0.isActive }
        return groupByFrequency(active)
    }

    /// Paused/inactive rules grouped by frequency
    var pausedByFrequency: [RecurrenceFrequencyGroup] {
        let paused = allRecurring.filter { !$0.isActive }
        return groupByFrequency(paused)
    }

    var body: some View {
        Group {
            if allRecurring.isEmpty {
                ContentUnavailableView(
                    "No Recurring Transactions",
                    systemImage: "arrow.triangle.2.circlepath",
                    description: Text("Set up recurring transactions to automatically log regular payments and income.")
                )
            } else {
                List {
                    if !activeByFrequency.isEmpty {
                        ForEach(activeByFrequency) { group in
                            Section(group.frequency.displayName) {
                                ForEach(group.items) { rule in
                                    Button {
                                        editingRecurring = rule
                                    } label: {
                                        RecurringTransactionRow(rule: rule)
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            modelContext.delete(rule)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            rule.isActive.toggle()
                                        } label: {
                                            Label("Pause", systemImage: "pause.circle")
                                        }
                                        .tint(.orange)
                                    }
                                }
                            }
                        }
                    }

                    if !pausedByFrequency.isEmpty {
                        ForEach(pausedByFrequency) { group in
                            Section("Paused -- \(group.frequency.displayName)") {
                                ForEach(group.items) { rule in
                                    Button {
                                        editingRecurring = rule
                                    } label: {
                                        RecurringTransactionRow(rule: rule)
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            modelContext.delete(rule)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            rule.isActive.toggle()
                                        } label: {
                                            Label("Resume", systemImage: "play.circle")
                                        }
                                        .tint(.green)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Recurring")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") {
                    showingAddRecurring = true
                }
            }
        }
        .sheet(isPresented: $showingAddRecurring) {
            AddRecurringTransactionView()
        }
        .sheet(item: $editingRecurring) { rule in
            EditRecurringTransactionView(rule: rule)
        }
    }

    private func groupByFrequency(_ items: [RecurringTransaction]) -> [RecurrenceFrequencyGroup] {
        let grouped = Dictionary(grouping: items) { $0.frequency }
        return RecurrenceFrequency.allCases.compactMap { freq in
            guard let items = grouped[freq], !items.isEmpty else { return nil }
            return RecurrenceFrequencyGroup(frequency: freq, items: items)
        }
    }
}

/// Groups recurring transactions by their frequency for sectioned display
struct RecurrenceFrequencyGroup: Identifiable {
    let frequency: RecurrenceFrequency
    let items: [RecurringTransaction]
    var id: String { frequency.rawValue }
}

// MARK: - Row

struct RecurringTransactionRow: View {
    let rule: RecurringTransaction
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    var body: some View {
        HStack {
            // Emoji or icon
            if rule.type == .transfer {
                Text("\u{21D4}\u{FE0F}")
                    .font(.title2)
                    .accessibilityHidden(true)
            } else if let category = rule.category {
                Text(category.emoji)
                    .font(.title2)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(rule.payee.isEmpty ? "Transfer" : rule.payee)
                        .font(.headline)
                    if !rule.isActive {
                        Text("Paused")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.orange)
                            .clipShape(.capsule)
                    }
                }
                HStack(spacing: 4) {
                    if let category = rule.category {
                        Text(category.name)
                    }
                    if let account = rule.account {
                        if rule.category != nil {
                            Text("\u{00B7}")
                        }
                        Text(account.name)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                TransactionAmountText(amount: rule.amount, type: rule.type)
                Text("Next: \(rule.nextOccurrence, format: .dateTime.day().month())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .opacity(rule.isActive ? 1 : 0.6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to edit")
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        parts.append(rule.payee.isEmpty ? "Transfer" : rule.payee)
        parts.append("\(formatGBP(rule.amount, currencyCode: currencyCode)) \(rule.type.rawValue)")
        parts.append(rule.frequency.displayName)
        if !rule.isActive { parts.append("paused") }
        parts.append("next on \(rule.nextOccurrence.formatted(.dateTime.day().month()))")
        return parts.joined(separator: ", ")
    }
}

// MARK: - Edit Recurring Transaction

struct EditRecurringTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]

    var categories: [Category] {
        allCategories.filter { !$0.isHeader }
    }

    let rule: RecurringTransaction

    @State private var amountText = ""
    @State private var payee = ""
    @State private var memo = ""
    @State private var type: TransactionType = .expense
    @State private var frequency: RecurrenceFrequency = .monthly
    @State private var startDate: Date = Date()
    @State private var hasEndDate = false
    @State private var endDate: Date = Date()
    @State private var isActive = true
    @State private var selectedAccount: Account?
    @State private var selectedTransferTo: Account?
    @State private var selectedCategory: Category?
    @State private var hasLoaded = false

    var shouldHaveCategory: Bool {
        if type == .transfer {
            guard let from = selectedAccount, let to = selectedTransferTo else { return false }
            return from.isBudget != to.isBudget
        }
        return selectedAccount?.isBudget ?? false
    }

    var canSave: Bool {
        guard let amount = Decimal(string: amountText), amount > 0 else { return false }
        guard selectedAccount != nil else { return false }

        if type == .transfer {
            guard let to = selectedTransferTo,
                  selectedAccount?.persistentModelID != to.persistentModelID else { return false }
            if shouldHaveCategory && selectedCategory == nil { return false }
            return true
        }

        guard !payee.isEmpty else { return false }
        if shouldHaveCategory && selectedCategory == nil { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                RecurringTransactionFormFields(
                    amountText: $amountText,
                    payee: $payee,
                    memo: $memo,
                    type: $type,
                    frequency: $frequency,
                    startDate: $startDate,
                    hasEndDate: $hasEndDate,
                    endDate: $endDate,
                    selectedAccount: $selectedAccount,
                    selectedTransferTo: $selectedTransferTo,
                    selectedCategory: $selectedCategory,
                    accounts: accounts,
                    categories: categories
                )

                Section {
                    Toggle("Active", isOn: $isActive)
                }

                Section {
                    Button(role: .destructive) {
                        modelContext.delete(rule)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Recurring Transaction")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { updateRule() }
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

                amountText = "\(rule.amount)"
                payee = rule.payee
                memo = rule.memo
                type = rule.type
                frequency = rule.frequency
                startDate = rule.startDate
                isActive = rule.isActive

                if let end = rule.endDate {
                    hasEndDate = true
                    endDate = end
                }

                selectedAccount = rule.account
                selectedTransferTo = rule.transferToAccount
                selectedCategory = rule.category
            }
        }
    }

    private func updateRule() {
        guard let amount = Decimal(string: amountText) else { return }

        rule.amount = amount
        rule.payee = type == .transfer && payee.isEmpty ? "Transfer" : payee
        rule.memo = memo
        rule.type = type
        rule.frequency = frequency
        rule.startDate = startDate
        rule.endDate = hasEndDate ? endDate : nil
        rule.isActive = isActive

        rule.account = selectedAccount
        rule.transferToAccount = type == .transfer ? selectedTransferTo : nil
        rule.category = shouldHaveCategory ? selectedCategory : nil

        dismiss()
    }
}

#Preview {
    NavigationStack {
        RecurringTransactionsView()
    }
    .modelContainer(for: [
        RecurringTransaction.self, Transaction.self,
        Account.self, Category.self, Payee.self
    ], inMemory: true)
}
