import SwiftUI
import SwiftData

/// A group of transactions sharing the same calendar day
struct TransactionGroup: Identifiable {
    let date: Date
    let transactions: [Transaction]
    var id: Date { date }
}

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    @State private var showingAddTransaction = false
    @State private var filterAccountID: PersistentIdentifier?  // nil = All Accounts
    @State private var editingTransaction: Transaction?
    @State private var searchText = ""
    @State private var showingRecurring = false
    @State private var transactionToDelete: Transaction?

    var filterAccount: Account? {
        guard let id = filterAccountID else { return nil }
        return accounts.first { $0.persistentModelID == id }
    }

    /// Step 1: filter by account
    var accountFiltered: [Transaction] {
        guard let account = filterAccount else { return allTransactions }
        return allTransactions.filter {
            $0.account?.persistentModelID == account.persistentModelID ||
            $0.transferToAccount?.persistentModelID == account.persistentModelID
        }
    }

    /// Step 2: filter by search text (payee, memo, category name)
    var filteredTransactions: [Transaction] {
        guard !searchText.isEmpty else { return accountFiltered }
        return accountFiltered.filter { transaction in
            transaction.payee.localizedStandardContains(searchText) ||
            transaction.memo.localizedStandardContains(searchText) ||
            (transaction.category?.name.localizedStandardContains(searchText) ?? false)
        }
    }

    /// Step 3: group by calendar day
    var groupedTransactions: [TransactionGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { TransactionGroup(date: $0.key, transactions: $0.value) }
    }

    var displayBalance: Decimal {
        if let account = filterAccount {
            return account.balance
        }
        return accounts.reduce(Decimal.zero) { $0 + $1.balance }
    }

    var budgetAccounts: [Account] {
        accounts.filter { $0.isBudget }
    }

    var trackingAccounts: [Account] {
        accounts.filter { !$0.isBudget }
    }

    var navigationTitle: String {
        filterAccount?.name ?? "Transactions"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: balance + account filter — solid background, above the list
            VStack(spacing: 0) {
                // Balance header — shows sign
                VStack(spacing: 4) {
                    Text(filterAccount == nil ? "Total Balance" : "Account Balance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    GBPText(amount: displayBalance, font: .title.bold(), showSign: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(filterAccount == nil ? "Total balance" : "Account balance"): \(formatGBP(displayBalance, currencyCode: currencyCode))\(displayBalance < 0 ? ", negative" : "")")

                // Account filter dropdown
                if accounts.count > 1 {
                    Menu {
                    Button {
                        filterAccountID = nil
                    } label: {
                        if filterAccountID == nil {
                            Label("All Accounts", systemImage: "checkmark")
                        } else {
                            Text("All Accounts")
                        }
                    }
                    Divider()
                    if !budgetAccounts.isEmpty {
                        Section("Budget Accounts") {
                            ForEach(budgetAccounts) { account in
                                Button {
                                    filterAccountID = account.persistentModelID
                                } label: {
                                    if filterAccountID == account.persistentModelID {
                                        Label(account.name, systemImage: "checkmark")
                                    } else {
                                        Text(account.name)
                                    }
                                }
                            }
                        }
                    }
                    if !trackingAccounts.isEmpty {
                        Section("Tracking Accounts") {
                            ForEach(trackingAccounts) { account in
                                Button {
                                    filterAccountID = account.persistentModelID
                                } label: {
                                    if filterAccountID == account.persistentModelID {
                                        Label(account.name, systemImage: "checkmark")
                                    } else {
                                        Text(account.name)
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(filterAccount?.name ?? "All Accounts")
                            .bold()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(.capsule)
                }
                .accessibilityLabel("Filter: \(filterAccount?.name ?? "All Accounts")")
                .accessibilityHint("Double tap to change account filter")
                .padding(.vertical, 8)
                }
            }
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            .zIndex(1)

            // Transaction list
            if groupedTransactions.isEmpty {
                Spacer()
                if !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ContentUnavailableView(
                        "No Transactions",
                        systemImage: "list.bullet.rectangle.fill",
                        description: Text("Tap + to add your first transaction.")
                    )
                }
                Spacer()
            } else {
                List {
                    ForEach(groupedTransactions) { group in
                        Section {
                            ForEach(group.transactions) { transaction in
                                Button {
                                    editingTransaction = transaction
                                } label: {
                                    TransactionRow(transaction: transaction, showAccount: filterAccount == nil, viewingAccount: filterAccount)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        transactionToDelete = transaction
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text(group.date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color(.systemBackground))
                                .listRowInsets(EdgeInsets())
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search payee, memo, or category")
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ProfileButton()
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button("Recurring", systemImage: "arrow.triangle.2.circlepath") {
                        showingRecurring = true
                    }
                    .accessibilityLabel("Recurring Transactions")
                    Button("Add", systemImage: "plus") {
                        showingAddTransaction = true
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showingRecurring) {
            RecurringTransactionsView()
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView(preselectedAccount: filterAccount)
        }
        .sheet(item: $editingTransaction) { transaction in
            EditTransactionView(transaction: transaction)
        }
        .confirmationDialog(
            "Delete Transaction?",
            isPresented: Binding(
                get: { transactionToDelete != nil },
                set: { if !$0 { transactionToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let transaction = transactionToDelete {
                    deleteSingleTransaction(transaction)
                    transactionToDelete = nil
                }
            }
        } message: {
            Text("This will update your account balance and budget. This cannot be undone.")
        }
        .sensoryFeedback(.selection, trigger: showingAddTransaction)
    }

    private func deleteSingleTransaction(_ transaction: Transaction) {
        modelContext.delete(transaction)
    }
}

struct TransactionsTab: View {
    var body: some View {
        NavigationStack {
            TransactionsView()
        }
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: Transaction
    var showAccount: Bool = true
    var viewingAccount: Account? = nil
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    var displayPayee: String {
        if transaction.type == .transfer && transaction.payee.isEmpty {
            return "Transfer"
        }
        return transaction.payee
    }

    /// Builds a descriptive accessibility label for the transaction
    private var accessibilityDescription: String {
        var parts: [String] = []
        parts.append(displayPayee)

        let formattedAmount = formatGBP(transaction.amount, currencyCode: currencyCode)
        switch transaction.type {
        case .expense:
            parts.append("expense of \(formattedAmount)")
        case .income:
            parts.append("income of \(formattedAmount)")
        case .transfer:
            parts.append("transfer of \(formattedAmount)")
            if let from = transaction.account, let to = transaction.transferToAccount {
                parts.append("from \(from.name) to \(to.name)")
            }
        }

        if transaction.type != .transfer, let category = transaction.category {
            parts.append("in \(category.name)")
        }
        if showAccount, let account = transaction.account, transaction.type != .transfer {
            parts.append("from \(account.name)")
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        HStack {
            if transaction.type == .transfer {
                Text("↔️")
                    .font(.title2)
                    .accessibilityHidden(true)
            } else if let category = transaction.category {
                Text(category.emoji)
                    .font(.title2)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "banknote")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(displayPayee)
                        .font(.headline)
                    if transaction.isAutoGenerated {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Recurring")
                    }
                }
                HStack(spacing: 4) {
                    if transaction.type == .transfer {
                        if let from = transaction.account, let to = transaction.transferToAccount {
                            Text("\(from.name) → \(to.name)")
                        }
                    } else {
                        if let category = transaction.category {
                            Text(category.name)
                        }
                        if showAccount, let account = transaction.account {
                            Text("·")
                            Text(account.name)
                        }
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if transaction.type == .transfer {
                    if let viewing = viewingAccount {
                        if transaction.transferToAccount?.persistentModelID == viewing.persistentModelID {
                            TransactionAmountText(amount: transaction.amount, type: .income)
                        } else {
                            TransactionAmountText(amount: transaction.amount, type: .expense)
                        }
                    } else {
                        TransactionAmountText(amount: transaction.amount, type: .transfer)
                    }
                } else {
                    TransactionAmountText(amount: transaction.amount, type: transaction.type)
                }
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to edit transaction")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TransactionsView()
    }
    .modelContainer(for: [Transaction.self, Account.self, Category.self, Payee.self, RecurringTransaction.self], inMemory: true)
}
