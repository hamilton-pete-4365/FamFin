import SwiftUI
import SwiftData

/// Shows all parsed transactions for review before importing.
/// The user can select/deselect individual transactions, change categories,
/// pick a target account, and confirm the import.
struct ImportReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]

    @State var transactions: [ImportedTransaction]
    let onImportComplete: (Int) -> Void

    @State private var selectedAccount: Account?
    @State private var importError: String?

    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    /// Subcategories only (not headers).
    private var categories: [Category] {
        allCategories.filter { !$0.isHeader }
    }

    private var selectedCount: Int {
        transactions.filter(\.isSelected).count
    }

    private var allSelected: Bool {
        transactions.allSatisfy(\.isSelected)
    }

    private var noneSelected: Bool {
        !transactions.contains(where: \.isSelected)
    }

    private var duplicateCount: Int {
        transactions.filter { $0.isSelected && $0.isPotentialDuplicate }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                ImportAccountSection(
                    selectedAccount: $selectedAccount,
                    accounts: accounts
                )

                ImportSelectionHeader(
                    selectedCount: selectedCount,
                    totalCount: transactions.count,
                    allSelected: allSelected,
                    onToggleAll: toggleAll
                )

                if duplicateCount > 0 {
                    Section {
                        Label(
                            "\(duplicateCount) potential duplicate\(duplicateCount == 1 ? "" : "s") detected",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                    }
                }

                Section {
                    ForEach(transactions.indices, id: \.self) { index in
                        ImportTransactionRow(
                            transaction: $transactions[index],
                            categories: categories,
                            currencyCode: currencyCode
                        )
                    }
                } header: {
                    Text("Transactions")
                }
            }

            // Import button at the bottom
            ImportActionBar(
                selectedCount: selectedCount,
                selectedAccount: selectedAccount,
                onImport: performImport
            )
        }
        .navigationTitle("Review Import")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Import Error", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .onAppear {
            // Default to the first account if there is exactly one
            if accounts.count == 1 {
                selectedAccount = accounts.first
            }
        }
    }

    private func toggleAll() {
        let newValue = !allSelected
        for index in transactions.indices {
            transactions[index].isSelected = newValue
        }
    }

    private func performImport() {
        guard let account = selectedAccount else {
            importError = "Please select an account to import into."
            return
        }

        let toImport = transactions.filter(\.isSelected)
        guard !toImport.isEmpty else {
            importError = "No transactions selected for import."
            return
        }

        var importedCount = 0

        for imported in toImport {
            let type: TransactionType = imported.isExpense ? .expense : .income
            let transaction = Transaction(
                amount: imported.amount,
                payee: imported.payee,
                memo: imported.memo,
                date: imported.date,
                type: type,
                isCleared: true
            )
            transaction.account = account

            // Assign category if the account is a budget account
            if account.isBudget {
                transaction.category = imported.suggestedCategory
            }

            modelContext.insert(transaction)

            // Update or create Payee record
            updatePayeeRecord(
                name: imported.payee,
                category: transaction.category
            )

            importedCount += 1
        }

        try? modelContext.save()
        onImportComplete(importedCount)

        // Pop back to the import entry point (the alert will show there)
        dismiss()
    }

    private func updatePayeeRecord(name: String, category: Category?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let descriptor = FetchDescriptor<Payee>(predicate: #Predicate { $0.name == trimmed })
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.recordUsage(category: category)
        } else {
            let newPayee = Payee(name: trimmed, lastUsedCategory: category)
            modelContext.insert(newPayee)
        }
    }
}

// MARK: - Account picker section

/// Picker for choosing which account to import transactions into.
private struct ImportAccountSection: View {
    @Binding var selectedAccount: Account?
    let accounts: [Account]

    private var budgetAccounts: [Account] {
        accounts.filter(\.isBudget)
    }

    private var trackingAccounts: [Account] {
        accounts.filter { !$0.isBudget }
    }

    var body: some View {
        Section("Import Into Account") {
            if accounts.isEmpty {
                Text("No accounts available. Create an account first.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Account", selection: $selectedAccount) {
                    Text("Select account").tag(Account?.none)
                    if !budgetAccounts.isEmpty {
                        Section("Budget Accounts") {
                            ForEach(budgetAccounts) { account in
                                Text(account.name).tag(Account?.some(account))
                            }
                        }
                    }
                    if !trackingAccounts.isEmpty {
                        Section("Tracking Accounts") {
                            ForEach(trackingAccounts) { account in
                                Text(account.name).tag(Account?.some(account))
                            }
                        }
                    }
                }
                .accessibilityLabel("Target account for import")
            }
        }
    }
}

// MARK: - Selection header

/// Shows the selection count and a toggle-all button.
private struct ImportSelectionHeader: View {
    let selectedCount: Int
    let totalCount: Int
    let allSelected: Bool
    let onToggleAll: () -> Void

    var body: some View {
        Section {
            HStack {
                Text("\(selectedCount) of \(totalCount) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(allSelected ? "Deselect All" : "Select All", action: onToggleAll)
                    .font(.subheadline)
            }
        }
    }
}

// MARK: - Transaction row

/// A single imported transaction row with selection toggle, category picker, and duplicate warning.
private struct ImportTransactionRow: View {
    @Binding var transaction: ImportedTransaction
    let categories: [Category]
    let currencyCode: String

    @Query(sort: \Category.sortOrder) private var allCategories: [Category]

    /// Categories grouped by header for the picker.
    private var groupedCategories: [CategoryGroup] {
        let nonSystem = allCategories.filter { !$0.isSystem && !$0.isHeader }
        var seen = Set<String>()
        var headerOrder: [(name: String, parent: Category)] = []
        for category in nonSystem {
            if let parent = category.parent, !seen.contains(parent.name) {
                seen.insert(parent.name)
                headerOrder.append((parent.name, parent))
            }
        }
        headerOrder.sort { $0.parent.sortOrder < $1.parent.sortOrder }

        var result: [CategoryGroup] = []
        for header in headerOrder {
            let subs = nonSystem
                .filter { $0.parent?.name == header.name }
                .sorted { $0.sortOrder < $1.sortOrder }
            if !subs.isEmpty {
                result.append(CategoryGroup(
                    headerName: "\(header.parent.emoji) \(header.name)",
                    subcategories: subs
                ))
            }
        }
        return result
    }

    var body: some View {
        HStack {
            Button {
                transaction.isSelected.toggle()
            } label: {
                Image(systemName: transaction.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(transaction.isSelected ? .accent : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(transaction.isSelected ? "Selected" : "Not selected")
            .accessibilityHint("Double tap to toggle selection")

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(transaction.payee)
                        .font(.headline)
                        .lineLimit(1)
                    if transaction.isPotentialDuplicate {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                            .accessibilityLabel("Potential duplicate")
                    }
                    Spacer()
                    Text(formatGBP(
                        transaction.isExpense ? -transaction.amount : transaction.amount,
                        currencyCode: currencyCode
                    ))
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(transaction.isExpense ? .red : .green)
                }

                HStack {
                    Text(transaction.date, format: .dateTime.day().month().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !transaction.memo.isEmpty {
                        Text("- \(transaction.memo)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                // Category picker
                Picker("Category", selection: $transaction.suggestedCategory) {
                    Text("Uncategorised").tag(Category?.none)
                    ForEach(groupedCategories) { group in
                        Section(group.headerName) {
                            ForEach(group.subcategories) { sub in
                                Text("\(sub.emoji) \(sub.name)")
                                    .tag(Category?.some(sub))
                            }
                        }
                    }
                }
                .font(.subheadline)
                .accessibilityLabel("Category for \(transaction.payee)")
            }
        }
        .padding(.vertical, 4)
        .opacity(transaction.isSelected ? 1.0 : 0.5)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Import action bar

/// Fixed bottom bar with the import button and count.
private struct ImportActionBar: View {
    let selectedCount: Int
    let selectedAccount: Account?
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                VStack(alignment: .leading) {
                    Text("\(selectedCount) transaction\(selectedCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .bold()
                    if let account = selectedAccount {
                        Text("into \(account.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Import Selected", systemImage: "square.and.arrow.down", action: onImport)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(selectedCount == 0 || selectedAccount == nil)
                    .accessibilityLabel("Import \(selectedCount) transactions")
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}
