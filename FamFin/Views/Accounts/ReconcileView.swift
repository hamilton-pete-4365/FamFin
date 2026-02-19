import SwiftUI
import SwiftData

/// Guided reconciliation flow for a single account.
///
/// Shows uncleared transactions with checkboxes. The user enters their
/// real-world statement balance, toggles transactions as cleared,
/// and when the cleared balance matches the statement balance
/// the "Finish" button becomes available.
struct ReconcileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    let account: Account

    @State private var statementBalanceText = ""
    @State private var localCleared: Set<PersistentIdentifier> = []
    @State private var hasLoadedInitial = false
    @State private var showingFinishConfirmation = false

    /// All transactions for this account (owned or incoming transfers)
    private var accountTransactions: [Transaction] {
        allTransactions.filter {
            $0.account?.persistentModelID == account.persistentModelID ||
            $0.transferToAccount?.persistentModelID == account.persistentModelID
        }
    }

    /// Transactions not yet cleared when reconciliation started
    private var unclearedTransactions: [Transaction] {
        accountTransactions.filter { !$0.isCleared }
    }

    /// Balance from already-cleared transactions
    private var previouslyClearedBalance: Decimal {
        var total: Decimal = .zero
        for tx in accountTransactions where tx.isCleared {
            total += signedAmount(for: tx)
        }
        return total
    }

    /// Balance from transactions the user is marking as cleared in this session
    private var newlyClearedBalance: Decimal {
        var total: Decimal = .zero
        for tx in unclearedTransactions where localCleared.contains(tx.persistentModelID) {
            total += signedAmount(for: tx)
        }
        return total
    }

    /// Total cleared balance (previously cleared + newly cleared)
    private var clearedBalance: Decimal {
        previouslyClearedBalance + newlyClearedBalance
    }

    /// Parsed statement balance from user input
    private var statementBalance: Decimal? {
        Decimal(string: statementBalanceText)
    }

    /// Difference between cleared balance and statement balance
    private var difference: Decimal? {
        guard let statement = statementBalance else { return nil }
        return clearedBalance - statement
    }

    /// Whether the reconciliation is balanced (difference is zero)
    private var isBalanced: Bool {
        difference == .zero
    }

    var body: some View {
        NavigationStack {
            List {
                // Statement balance entry
                Section {
                    HStack {
                        Text("Statement Balance")
                        Spacer()
                        TextField("0.00", text: $statementBalanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 150)
                    }
                } footer: {
                    Text("Enter your real-world account balance from your bank statement.")
                }

                // Summary
                Section("Reconciliation Summary") {
                    HStack {
                        Text("Cleared Balance")
                            .foregroundStyle(.secondary)
                        Spacer()
                        GBPText(amount: clearedBalance, font: .body)
                    }

                    if let diff = difference {
                        HStack {
                            Text("Difference")
                                .foregroundStyle(.secondary)
                            Spacer()
                            GBPText(amount: diff, font: .body.bold())
                                .foregroundStyle(isBalanced ? .green : .red)
                        }
                    }
                }

                // Uncleared transactions to check off
                if !unclearedTransactions.isEmpty {
                    Section("Uncleared Transactions") {
                        ForEach(unclearedTransactions) { transaction in
                            Button {
                                toggleCleared(transaction)
                            } label: {
                                HStack {
                                    Image(systemName: localCleared.contains(transaction.persistentModelID)
                                        ? "checkmark.circle.fill"
                                        : "circle")
                                        .foregroundStyle(localCleared.contains(transaction.persistentModelID)
                                            ? .green
                                            : .secondary)
                                        .font(.title3)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(transaction.payee.isEmpty ? "Transfer" : transaction.payee)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        Text(transaction.date, format: .dateTime.day().month().year())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    TransactionAmountText(
                                        amount: transaction.amount,
                                        type: transactionDisplayType(for: transaction)
                                    )
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(transaction.payee), \(formatGBP(transaction.amount, currencyCode: currencyCode)), \(localCleared.contains(transaction.persistentModelID) ? "cleared" : "uncleared")")
                            .accessibilityHint("Double tap to toggle cleared status")
                        }
                    }
                } else {
                    Section {
                        Text("All transactions are already cleared.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Reconcile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        showingFinishConfirmation = true
                    }
                    .disabled(!isBalanced)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .alert("Finish Reconciliation?", isPresented: $showingFinishConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Finish") {
                    finishReconciliation()
                }
            } message: {
                Text("This will mark \(localCleared.count) transaction\(localCleared.count == 1 ? "" : "s") as cleared and record the reconciliation date.")
            }
            .onAppear {
                guard !hasLoadedInitial else { return }
                hasLoadedInitial = true
            }
        }
    }

    private func toggleCleared(_ transaction: Transaction) {
        if localCleared.contains(transaction.persistentModelID) {
            localCleared.remove(transaction.persistentModelID)
        } else {
            localCleared.insert(transaction.persistentModelID)
        }
    }

    private func finishReconciliation() {
        // Mark all newly cleared transactions
        for tx in unclearedTransactions where localCleared.contains(tx.persistentModelID) {
            tx.isCleared = true
        }
        account.lastReconciledDate = Date()
        try? modelContext.save()
        dismiss()
    }

    /// Signed amount for balance calculation, relative to this account
    private func signedAmount(for transaction: Transaction) -> Decimal {
        if transaction.transferToAccount?.persistentModelID == account.persistentModelID {
            return transaction.amount // incoming transfer
        }
        switch transaction.type {
        case .income: return transaction.amount
        case .expense: return -transaction.amount
        case .transfer: return -transaction.amount // outgoing transfer
        }
    }

    /// Display type for the amount text, relative to this account
    private func transactionDisplayType(for transaction: Transaction) -> TransactionType {
        if transaction.type == .transfer {
            if transaction.transferToAccount?.persistentModelID == account.persistentModelID {
                return .income
            }
            return .expense
        }
        return transaction.type
    }
}
