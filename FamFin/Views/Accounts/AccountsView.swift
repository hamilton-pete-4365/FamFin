import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @State private var showingAddAccount = false
    @State private var editingAccount: Account?
    @State private var isEditing = false
    @State private var expandedSections: Set<String> = ["Budget", "Tracking"]

    /// Called when user taps an account to view its transactions
    var onSelectAccount: ((PersistentIdentifier) -> Void)?

    var budgetAccounts: [Account] {
        accounts.filter { $0.isBudget }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var trackingAccounts: [Account] {
        accounts.filter { !$0.isBudget }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var budgetBalance: Decimal {
        budgetAccounts.reduce(Decimal.zero) { $0 + $1.balance }
    }

    var trackingBalance: Decimal {
        trackingAccounts.reduce(Decimal.zero) { $0 + $1.balance }
    }

    var body: some View {
        NavigationStack {
            Group {
                if accounts.isEmpty {
                    ContentUnavailableView(
                        "No Accounts",
                        systemImage: "banknote.fill",
                        description: Text("Add your first account to start tracking your money.")
                    )
                } else {
                    List {
                        // Budget accounts
                        if !budgetAccounts.isEmpty {
                            Section {
                                // Collapsible section header
                                Button {
                                    withAnimation {
                                        if expandedSections.contains("Budget") {
                                            expandedSections.remove("Budget")
                                        } else {
                                            expandedSections.insert("Budget")
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: expandedSections.contains("Budget") ? "chevron.down" : "chevron.right")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.secondary)
                                            .frame(width: 14)
                                        Text("BUDGET ACCOUNTS")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        GBPText(amount: budgetBalance, font: .subheadline)
                                    }
                                }
                                .tint(.primary)
                                .listRowBackground(Color(.secondarySystemGroupedBackground))
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

                                if expandedSections.contains("Budget") {
                                    ForEach(budgetAccounts) { account in
                                        Button {
                                            if isEditing {
                                                editingAccount = account
                                            } else {
                                                onSelectAccount?(account.persistentModelID)
                                            }
                                        } label: {
                                            AccountRow(account: account)
                                        }
                                        .tint(.primary)
                                    }
                                    .onDelete { offsets in
                                        deleteAccounts(offsets, from: budgetAccounts)
                                    }
                                    .onMove { source, destination in
                                        moveAccounts(source: source, destination: destination, inList: budgetAccounts)
                                    }
                                }
                            }
                        }

                        // Tracking accounts
                        if !trackingAccounts.isEmpty {
                            Section {
                                // Collapsible section header
                                Button {
                                    withAnimation {
                                        if expandedSections.contains("Tracking") {
                                            expandedSections.remove("Tracking")
                                        } else {
                                            expandedSections.insert("Tracking")
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: expandedSections.contains("Tracking") ? "chevron.down" : "chevron.right")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.secondary)
                                            .frame(width: 14)
                                        Text("TRACKING ACCOUNTS")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        GBPText(amount: trackingBalance, font: .subheadline)
                                    }
                                }
                                .tint(.primary)
                                .listRowBackground(Color(.secondarySystemGroupedBackground))
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

                                if expandedSections.contains("Tracking") {
                                    ForEach(trackingAccounts) { account in
                                        Button {
                                            if isEditing {
                                                editingAccount = account
                                            } else {
                                                onSelectAccount?(account.persistentModelID)
                                            }
                                        } label: {
                                            AccountRow(account: account)
                                        }
                                        .tint(.primary)
                                    }
                                    .onDelete { offsets in
                                        deleteAccounts(offsets, from: trackingAccounts)
                                    }
                                    .onMove { source, destination in
                                        moveAccounts(source: source, destination: destination, inList: trackingAccounts)
                                    }
                                }
                            }
                        }
                    }
                    .listSectionSpacing(4)
                    .environment(\.editMode, .constant(isEditing ? .active : .inactive))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !accounts.isEmpty {
                        Button(isEditing ? "Done" : "Edit") {
                            withAnimation {
                                isEditing.toggle()
                            }
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Accounts")
                        .font(.headline)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") {
                        showingAddAccount = true
                    }
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                AddAccountView(nextSortOrder: accounts.count)
            }
            .sheet(item: $editingAccount) { account in
                EditAccountView(account: account)
            }
        }
    }

    private func deleteAccounts(_ offsets: IndexSet, from list: [Account]) {
        for index in offsets {
            modelContext.delete(list[index])
        }
    }

    private func moveAccounts(source: IndexSet, destination: Int, inList list: [Account]) {
        var mutable = list
        mutable.move(fromOffsets: source, toOffset: destination)
        for (index, account) in mutable.enumerated() {
            account.sortOrder = index
        }
    }
}

struct AccountRow: View {
    let account: Account

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.body)
                Text(account.type.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            GBPText(amount: account.balance, font: .body)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Account

struct AddAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var nextSortOrder: Int = 0

    @State private var name = ""
    @State private var type: AccountType = .current
    @State private var isBudget: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                TextField("Account Name", text: $name)

                Picker("Type", selection: $type) {
                    ForEach(AccountType.allCases) { accountType in
                        Text(accountType.rawValue).tag(accountType)
                    }
                }

                Picker("Category", selection: $isBudget) {
                    Text("Budget").tag(true)
                    Text("Tracking").tag(false)
                }
                .pickerStyle(.segmented)

                if isBudget {
                    Text("Transactions in this account will be part of your monthly budget.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Tracks the balance separately. Not included in budget categories.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let account = Account(
                            name: name,
                            type: type,
                            isBudget: isBudget,
                            sortOrder: nextSortOrder
                        )
                        modelContext.insert(account)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onChange(of: type) { _, newType in
                isBudget = newType.defaultIsBudget
            }
        }
    }
}

// MARK: - Edit Account

struct EditAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let account: Account

    @State private var name = ""
    @State private var type: AccountType = .current
    @State private var isBudget: Bool = true
    @State private var hasLoaded = false
    @State private var showingDeleteConfirm = false
    @State private var showingReclassifyConfirm = false

    /// Whether the user is changing the Budget/Tracking classification
    private var isBudgetChanged: Bool {
        hasLoaded && isBudget != account.isBudget
    }

    /// Whether this reclassification affects existing transactions
    private var reclassifyAffectsTransactions: Bool {
        isBudgetChanged && !account.transactions.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Account Name", text: $name)

                Picker("Type", selection: $type) {
                    ForEach(AccountType.allCases) { accountType in
                        Text(accountType.rawValue).tag(accountType)
                    }
                }

                Picker("Category", selection: $isBudget) {
                    Text("Budget").tag(true)
                    Text("Tracking").tag(false)
                }
                .pickerStyle(.segmented)

                if isBudget {
                    Text("Transactions in this account will be part of your monthly budget.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Tracks the balance separately. Not included in budget categories.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if reclassifyAffectsTransactions {
                    let count = account.transactions.count
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color("WarningColor"))
                        Text("Changing this will affect \(count) existing \(count == 1 ? "transaction" : "transactions") and recalculate your budget.")
                            .font(.caption)
                            .foregroundStyle(Color("WarningColor"))
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Account")
                            Spacer()
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if reclassifyAffectsTransactions {
                            showingReclassifyConfirm = true
                        } else {
                            saveAndDismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
            .alert("Delete Account?", isPresented: $showingDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(account)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will also delete all transactions in this account. This cannot be undone.")
            }
            .alert("Change Account Type?", isPresented: $showingReclassifyConfirm) {
                Button("Change", role: .destructive) {
                    saveAndDismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                let destination = isBudget ? "Budget" : "Tracking"
                let count = account.transactions.count
                Text("Moving this account to \(destination) will affect how \(count) \(count == 1 ? "transaction is" : "transactions are") counted in your budget.")
            }
            .onAppear {
                guard !hasLoaded else { return }
                hasLoaded = true
                name = account.name
                type = account.type
                isBudget = account.isBudget
            }
        }
    }

    private func saveAndDismiss() {
        account.name = name
        account.type = type
        account.isBudget = isBudget
        dismiss()
    }
}

#Preview {
    AccountsView()
        .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
}
