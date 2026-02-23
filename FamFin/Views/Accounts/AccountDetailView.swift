import SwiftUI
import SwiftData

/// Detail view for a single account, pushed within the Accounts tab.
/// Shows the account balance, recent transactions, and a reconcile button.
struct AccountDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    let accountID: PersistentIdentifier

    @State private var account: Account?
    @State private var editingTransaction: Transaction?
    @State private var showingAddTransaction = false
    @State private var showingEditAccount = false
    @State private var showingReconcile = false
    @State private var searchText = ""

    /// Transactions belonging to this account (owned or incoming transfers)
    private var accountTransactions: [Transaction] {
        guard let account else { return [] }
        return allTransactions.filter {
            $0.account?.persistentModelID == account.persistentModelID ||
            $0.transferToAccount?.persistentModelID == account.persistentModelID
        }
    }

    /// Filtered by search text
    private var filteredTransactions: [Transaction] {
        guard !searchText.isEmpty else { return accountTransactions }
        return accountTransactions.filter { transaction in
            transaction.payee.localizedStandardContains(searchText) ||
            transaction.memo.localizedStandardContains(searchText) ||
            (transaction.category?.name.localizedStandardContains(searchText) ?? false)
        }
    }

    /// Grouped by calendar day
    private var groupedTransactions: [TransactionGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { TransactionGroup(date: $0.key, transactions: $0.value) }
    }

    /// Count of uncleared transactions
    private var unclearedCount: Int {
        accountTransactions.filter { !$0.isCleared }.count
    }

    var body: some View {
        Group {
            if let account {
                VStack(spacing: 0) {
                    // Balance header
                    VStack(spacing: 4) {
                        Text("Account Balance")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        GBPText(amount: account.balance, font: .title.bold(), showSign: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Account balance: \(formatGBP(account.balance, currencyCode: currencyCode))\(account.balance < 0 ? ", negative" : "")")

                    // Reconcile button
                    if unclearedCount > 0 {
                        Button {
                            showingReconcile = true
                        } label: {
                            Label(
                                "\(unclearedCount) uncleared transaction\(unclearedCount == 1 ? "" : "s")",
                                systemImage: "checkmark.circle"
                            )
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(.capsule)
                        }
                        .padding(.bottom, 8)
                    }

                    Divider()

                    // Transaction list
                    if groupedTransactions.isEmpty {
                        Spacer()
                        if !searchText.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                        } else {
                            ContentUnavailableView(
                                "No Transactions",
                                systemImage: "list.bullet.rectangle.fill",
                                description: Text("Tap + to add a transaction to this account.")
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
                                            HStack {
                                                TransactionRow(
                                                    transaction: transaction,
                                                    showAccount: false,
                                                    viewingAccount: account
                                                )
                                                if transaction.isCleared {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.caption)
                                                        .foregroundStyle(.green)
                                                        .accessibilityLabel("Cleared")
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                transaction.isCleared.toggle()
                                            } label: {
                                                Label(
                                                    transaction.isCleared ? "Unclear" : "Clear",
                                                    systemImage: transaction.isCleared ? "xmark.circle" : "checkmark.circle"
                                                )
                                            }
                                            .tint(transaction.isCleared ? .orange : .green)
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                deleteTransaction(transaction)
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
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search transactions")
            } else {
                ContentUnavailableView(
                    "Account Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This account may have been deleted.")
                )
            }
        }
        .navigationTitle(account?.name ?? "Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if account != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Add Transaction", systemImage: "plus") {
                            showingAddTransaction = true
                        }
                        Button("Edit Account", systemImage: "pencil") {
                            showingEditAccount = true
                        }
                        if unclearedCount > 0 {
                            Button("Reconcile", systemImage: "checkmark.circle") {
                                showingReconcile = true
                            }
                        }
                    } label: {
                        Label("Options", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView(preselectedAccount: account)
        }
        .sheet(item: $editingTransaction) { transaction in
            EditTransactionView(transaction: transaction)
        }
        .sheet(isPresented: $showingEditAccount) {
            if let account {
                EditAccountView(account: account)
            }
        }
        .sheet(isPresented: $showingReconcile) {
            if let account {
                ReconcileView(account: account)
            }
        }
        .onAppear { loadAccount() }
    }

    private func loadAccount() {
        account = modelContext.model(for: accountID) as? Account
    }

    private func deleteTransaction(_ transaction: Transaction) {
        modelContext.delete(transaction)
    }
}
