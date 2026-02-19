import SwiftUI
import SwiftData

/// Pushed detail view for a budget category, showing summary, linked goals,
/// and transactions for the selected month.
struct CategoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SharingManager.self) private var sharingManager
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var allGoals: [SavingsGoal]
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    let category: Category
    let month: Date

    @State private var editingTransaction: Transaction?
    @State private var showingAddTransaction = false
    @State private var transactionToDelete: Transaction?

    private var monthTransactions: [Transaction] {
        let calendar = Calendar.current
        return allTransactions.filter { transaction in
            guard let cat = transaction.category else { return false }
            guard cat.persistentModelID == category.persistentModelID else { return false }
            return calendar.isDate(transaction.date, equalTo: month, toGranularity: .month)
        }
    }

    private var linkedGoals: [SavingsGoal] {
        allGoals.filter { $0.linkedCategory?.persistentModelID == category.persistentModelID }
    }

    private var budgeted: Decimal { category.budgeted(in: month) }
    private var activity: Decimal { category.activity(in: month) }
    private var available: Decimal { category.available(through: month) }

    var body: some View {
        VStack(spacing: 0) {
            // Summary header
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text(category.emoji)
                        .font(.title2)
                    Text(category.name)
                        .font(.title3.bold())
                    Spacer()
                }
                .padding(.horizontal, 20)

                // Three-column summary
                HStack(spacing: 0) {
                    CategoryStatColumn(label: "Budgeted", amount: budgeted)
                    CategoryStatColumn(label: "Activity", amount: activity)
                    CategoryStatColumn(label: "Available", amount: available, accentPositive: true, isNegativeWarning: available < 0)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .padding(.top, 16)
            .background(Color(.systemBackground))

            // Linked goals section
            if !linkedGoals.isEmpty {
                Divider()

                VStack(spacing: 8) {
                    ForEach(linkedGoals) { goal in
                        NavigationLink(value: goal.persistentModelID) {
                            CategoryGoalRow(goal: goal, month: month)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }

            Divider()

            // Transaction list
            if monthTransactions.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("No transactions this month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(monthTransactions) { transaction in
                        Button {
                            editingTransaction = transaction
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(transaction.payee)
                                        .font(.body)
                                    Text(transaction.date, format: .dateTime.day().month(.abbreviated))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                TransactionAmountText(amount: transaction.amount, type: transaction.type, font: .body)
                            }
                            .padding(.vertical, 4)
                        }
                        .tint(.primary)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                transactionToDelete = transaction
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Transaction", systemImage: "plus") {
                    showingAddTransaction = true
                }
            }
        }
        .navigationDestination(for: PersistentIdentifier.self) { goalID in
            GoalDetailView(goalID: goalID)
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView(preselectedCategory: category)
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
                    deleteTransaction(transaction)
                    transactionToDelete = nil
                }
            }
        } message: {
            Text("This will update your account balance and budget. This cannot be undone.")
        }
    }

    private func deleteTransaction(_ transaction: Transaction) {
        if sharingManager.isShared {
            sharingManager.logActivity(
                message: "\(sharingManager.currentUserName) deleted \(transaction.payee)",
                type: .deletedTransaction,
                context: modelContext
            )
        }
        modelContext.delete(transaction)
    }
}

// MARK: - Category Stat Column

struct CategoryStatColumn: View {
    let label: String
    let amount: Decimal
    var accentPositive: Bool = false
    var isNegativeWarning: Bool = false
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    var body: some View {
        VStack(spacing: 4) {
            GBPText(amount: amount, font: .headline, accentPositive: accentPositive)
                .foregroundStyle(isNegativeWarning ? .red : .primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(formatGBP(amount, currencyCode: currencyCode))")
    }
}
