import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @State private var showingAddAccount = false
    @State private var editingAccount: Account?
    @State private var isEditing = false

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

    var totalBalance: Decimal {
        accounts.reduce(Decimal.zero) { $0 + $1.balance }
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
                        // Net worth header
                        Section {
                            VStack(spacing: 4) {
                                GBPText(amount: totalBalance, font: .title2.bold())
                                Text("Net Worth")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .listRowBackground(Color.accentColor.opacity(0.1))
                        }

                        // Budget accounts
                        if !budgetAccounts.isEmpty {
                            Section {
                                // Section header row (inline, styled like budget tab)
                                HStack {
                                    Text("BUDGET ACCOUNTS")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    GBPText(amount: budgetBalance, font: .caption)
                                }
                                .listRowBackground(Color(.secondarySystemGroupedBackground).opacity(0.5))
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                                ForEach(budgetAccounts) { account in
                                    if isEditing {
                                        // In edit mode: tap to edit, no navigation
                                        Button {
                                            editingAccount = account
                                        } label: {
                                            AccountRow(account: account)
                                        }
                                        .tint(.primary)
                                    } else {
                                        // Normal mode: tap to navigate to transactions
                                        NavigationLink(value: account) {
                                            AccountRow(account: account)
                                        }
                                    }
                                }
                                .onDelete { offsets in
                                    deleteAccounts(offsets, from: budgetAccounts)
                                }
                                .onMove { source, destination in
                                    moveAccounts(source: source, destination: destination, inList: budgetAccounts)
                                }
                            }
                        }

                        // Tracking accounts
                        if !trackingAccounts.isEmpty {
                            Section {
                                // Section header row (inline, styled like budget tab)
                                HStack {
                                    Text("TRACKING ACCOUNTS")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    GBPText(amount: trackingBalance, font: .caption)
                                }
                                .listRowBackground(Color(.secondarySystemGroupedBackground).opacity(0.5))
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                                ForEach(trackingAccounts) { account in
                                    if isEditing {
                                        Button {
                                            editingAccount = account
                                        } label: {
                                            AccountRow(account: account)
                                        }
                                        .tint(.primary)
                                    } else {
                                        NavigationLink(value: account) {
                                            AccountRow(account: account)
                                        }
                                    }
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
                    .listSectionSpacing(4)
                    .environment(\.editMode, .constant(isEditing ? .active : .inactive))
                    .navigationDestination(for: Account.self) { account in
                        TransactionsView(initialAccount: account)
                    }
                }
            }
            .navigationTitle("Accounts")
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
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddAccount = true
                    } label: {
                        Image(systemName: "plus")
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
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.subheadline)
                Text(account.type.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            GBPText(amount: account.balance, font: .subheadline)
        }
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
            .navigationTitle("Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        account.name = name
                        account.type = type
                        account.isBudget = isBudget
                        dismiss()
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
            .onAppear {
                guard !hasLoaded else { return }
                hasLoaded = true
                name = account.name
                type = account.type
                isBudget = account.isBudget
            }
        }
    }
}

#Preview {
    AccountsView()
        .modelContainer(for: [Account.self, Transaction.self], inMemory: true)
}
