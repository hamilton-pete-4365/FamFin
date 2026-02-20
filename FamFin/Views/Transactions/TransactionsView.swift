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
    @Environment(SharingManager.self) private var sharingManager
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
        if sharingManager.isShared {
            let message = "\(sharingManager.currentUserName) deleted \(transaction.payee) (\(transaction.amount))"
            sharingManager.logActivity(
                message: message,
                type: .deletedTransaction,
                context: modelContext
            )
        }
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

// MARK: - Payee Autocomplete Helper

struct PayeeSuggestionField: View {
    @Binding var payeeText: String
    @Binding var suggestedCategory: Category?
    var isOptional: Bool = false

    @Query(sort: \Payee.lastUsedDate, order: .reverse) private var allPayees: [Payee]
    @State private var showingSuggestions = false

    var matchingPayees: [Payee] {
        guard !payeeText.isEmpty else { return [] }
        return allPayees.filter { $0.name.localizedStandardContains(payeeText) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(isOptional ? "Payee (optional)" : "Payee", text: $payeeText)
                .autocorrectionDisabled()
                .onChange(of: payeeText) { _, newValue in
                    showingSuggestions = !newValue.isEmpty && !matchingPayees.isEmpty
                }

            if showingSuggestions && !matchingPayees.isEmpty {
                Divider()
                ForEach(matchingPayees) { payee in
                    Button {
                        payeeText = payee.name
                        showingSuggestions = false
                        if let lastCat = payee.lastUsedCategory {
                            suggestedCategory = lastCat
                        }
                    } label: {
                        HStack {
                            Text(payee.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if let cat = payee.lastUsedCategory {
                                Text("\(cat.emoji) \(cat.name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

// MARK: - Shared Form Fields

/// Helper to group subcategories under their header names for display in Pickers
struct CategoryGroup: Identifiable {
    let headerName: String
    let subcategories: [Category]
    var id: String { headerName }
}

struct TransactionFormFields: View {
    @Binding var amountText: String
    @Binding var payee: String
    @Binding var memo: String
    @Binding var date: Date
    @Binding var type: TransactionType
    @Binding var selectedAccount: Account?
    @Binding var selectedTransferTo: Account?
    @Binding var selectedCategory: Category?

    let accounts: [Account]
    let categories: [Category]
    var autoFocusAmount: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var budgetAccounts: [Account] {
        accounts.filter { $0.isBudget }
    }

    var trackingAccounts: [Account] {
        accounts.filter { !$0.isBudget }
    }

    /// Raw digits string — user types "1536", we store "1536" and display £15.36
    @State private var rawDigits: String = ""
    @State private var hasLoadedAmount = false
    @State private var showDatePicker = false
    @FocusState private var amountFocused: Bool
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    /// Pence value from raw digits
    private var amountInPence: Int {
        Int(rawDigits) ?? 0
    }

    /// Formatted display string: styled by transaction type
    private var amountDisplayString: String {
        let base = formatPence(amountInPence, currencyCode: currencyCode)
        switch type {
        case .expense:
            return "-\(base)"
        case .income:
            return "+\(base)"
        case .transfer:
            return base
        }
    }

    /// Colour for the amount display based on transaction type
    private var amountColor: Color {
        guard amountInPence > 0 else { return .secondary }
        switch type {
        case .expense: return .red
        case .income: return .green
        case .transfer: return .primary
        }
    }

    /// Sync the amountText binding from minor units value (for save compatibility)
    private func syncAmountText() {
        let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
        let units = amountInPence
        if currency.hasMinorUnits {
            let major = units / 100
            let minor = units % 100
            let minorStr = minor < 10 ? "0\(minor)" : "\(minor)"
            amountText = "\(major).\(minorStr)"
        } else {
            amountText = "\(units)"
        }
    }

    /// Whether this transfer crosses the Budget/Tracking boundary
    var transferNeedsCategory: Bool {
        guard type == .transfer,
              let from = selectedAccount,
              let to = selectedTransferTo else { return false }
        return from.isBudget != to.isBudget
    }

    /// Is the selected account a Budget account?
    var selectedAccountIsBudget: Bool {
        selectedAccount?.isBudget ?? false
    }

    /// Whether category picker should be shown.
    /// Budget account income/expense: YES. Tracking account: NO.
    /// Transfer: only for cross-boundary.
    var showCategory: Bool {
        if type == .transfer {
            return transferNeedsCategory
        }
        return selectedAccountIsBudget
    }

    /// The "To Budget" system category (if it exists)
    var toBudgetCategory: Category? {
        categories.first { $0.isSystem && $0.name == DefaultCategories.toBudgetName }
    }

    /// Categories grouped by their parent header, preserving sort order.
    /// Excludes the "To Budget" system category (shown separately at top of picker).
    var groupedCategories: [CategoryGroup] {
        // Collect unique headers in order
        var seen = Set<String>()
        var headerOrder: [(name: String, parent: Category)] = []
        for category in categories where !category.isSystem {
            if let parent = category.parent, !seen.contains(parent.name) {
                seen.insert(parent.name)
                headerOrder.append((parent.name, parent))
            }
        }
        // Sort headers by their sortOrder
        headerOrder.sort { $0.parent.sortOrder < $1.parent.sortOrder }

        var result: [CategoryGroup] = []
        for header in headerOrder {
            let subs = categories
                .filter { !$0.isSystem && $0.parent?.name == header.name }
                .sorted { $0.sortOrder < $1.sortOrder }
            if !subs.isEmpty {
                result.append(CategoryGroup(headerName: "\(header.parent.emoji) \(header.name)", subcategories: subs))
            }
        }
        // Also add any orphan (no parent, non-system) subcategories
        let orphans = categories
            .filter { !$0.isSystem && $0.parent == nil && !$0.isHeader }
            .sorted { $0.sortOrder < $1.sortOrder }
        if !orphans.isEmpty {
            result.append(CategoryGroup(headerName: "Other", subcategories: orphans))
        }
        return result
    }

    var body: some View {
        // Amount — pence-based entry (type digits, fills from right like ATM)
        Section {
            ZStack {
                // Hidden text field bound to rawDigits — only digits allowed
                TextField("", text: $rawDigits)
                    .keyboardType(.numberPad)
                    .focused($amountFocused)
                    .opacity(0.01)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
                    .onChange(of: amountFocused) { _, focused in
                        // When re-focusing, select all so next keypress replaces.
                        // Don't clear immediately — keep the display until user types.
                    }
                    .onChange(of: rawDigits) { _, newValue in
                        // Strip any non-digit characters
                        let digits = newValue.filter { $0.isNumber }
                        // Remove leading zeros (but keep at least empty string)
                        let trimmed = String(digits.drop(while: { $0 == "0" }))
                        // Cap length at 8 digits (£999,999.99)
                        let capped = String(trimmed.prefix(8))
                        if rawDigits != capped {
                            rawDigits = capped
                        }
                        syncAmountText()
                    }

                // Visible display — tap to focus the hidden field
                Button {
                    amountFocused = true
                } label: {
                    HStack {
                        Text(amountDisplayString)
                            .font(.largeTitle.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(amountColor)
                            .contentTransition(reduceMotion ? .identity : .numericText())
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Amount: \(amountDisplayString)")
                .accessibilityHint("Double tap to edit amount")

                if amountInPence > 0 {
                    // Backspace overlay (top-right of ZStack area)
                    HStack {
                        Spacer()
                        Button("Delete last digit", systemImage: "delete.backward") {
                            rawDigits = String(rawDigits.dropLast())
                            syncAmountText()
                        }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                        .font(.title3)
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear {
            // Load initial amount from amountText (for edit mode)
            if !hasLoadedAmount {
                hasLoadedAmount = true
                if let decimal = Decimal(string: amountText), decimal > 0 {
                    let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
                    let multiplier = Decimal(currency.minorUnitMultiplier)
                    let minorUnits = NSDecimalNumber(decimal: decimal * multiplier).intValue
                    rawDigits = minorUnits > 0 ? "\(minorUnits)" : ""
                }
                if autoFocusAmount {
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        amountFocused = true
                    }
                }
            }
        }

        // Type selector
        Section {
            Picker("Type", selection: $type) {
                ForEach(TransactionType.allCases) { transType in
                    Text(transType.rawValue).tag(transType)
                }
            }
            .pickerStyle(.segmented)
        }

        // Details — payee is optional for transfers
        Section("Details") {
            PayeeSuggestionField(
                payeeText: $payee,
                suggestedCategory: $selectedCategory,
                isOptional: type == .transfer
            )
            TextField("Memo (optional)", text: $memo)

            // Date row: tap to toggle inline picker
            Button {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                withAnimation(reduceMotion ? nil : .default) { showDatePicker.toggle() }
            } label: {
                HStack {
                    Text("Date")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(date, format: .dateTime.day().month().year())
                        .foregroundStyle(showDatePicker ? Color.accentColor : .secondary)
                }
            }

            if showDatePicker {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .onChange(of: date) { _, _ in
                        withAnimation(reduceMotion ? nil : .default) { showDatePicker = false }
                    }
            }
        }

        // Account(s)
        if type == .transfer {
            Section("Transfer From") {
                if accounts.isEmpty {
                    Text("Add an account first")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("From", selection: $selectedAccount) {
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
                }
            }
            Section("Transfer To") {
                Picker("To", selection: $selectedTransferTo) {
                    Text("Select account").tag(Account?.none)
                    let filteredBudget = budgetAccounts.filter {
                        $0.persistentModelID != selectedAccount?.persistentModelID
                    }
                    let filteredTracking = trackingAccounts.filter {
                        $0.persistentModelID != selectedAccount?.persistentModelID
                    }
                    if !filteredBudget.isEmpty {
                        Section("Budget Accounts") {
                            ForEach(filteredBudget) { account in
                                Text(account.name).tag(Account?.some(account))
                            }
                        }
                    }
                    if !filteredTracking.isEmpty {
                        Section("Tracking Accounts") {
                            ForEach(filteredTracking) { account in
                                Text(account.name).tag(Account?.some(account))
                            }
                        }
                    }
                }

                if let from = selectedAccount, let to = selectedTransferTo,
                   from.persistentModelID == to.persistentModelID {
                    Text("From and To accounts must be different.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if transferNeedsCategory {
                    Text("This transfer crosses Budget/Tracking boundary and needs a category.")
                        .font(.caption)
                        .foregroundStyle(Color("WarningColor"))
                }
            }
        } else {
            // Account is required for income/expense
            Section("Account") {
                if accounts.isEmpty {
                    Text("Add an account first")
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

                    if selectedAccount == nil {
                        Text("An account is required.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }

        // Category — shown for Budget account income/expense, or for cross-boundary transfers
        if showCategory {
            Section("Category") {
                if categories.isEmpty {
                    Text("No categories yet")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Category", selection: $selectedCategory) {
                        // "To Budget" at the top as a real category
                        if let toBudget = toBudgetCategory {
                            Text("💰 To Budget").tag(Category?.some(toBudget))
                        }
                        ForEach(groupedCategories) { group in
                            Section(group.headerName) {
                                ForEach(group.subcategories) { sub in
                                    Text("\(sub.emoji) \(sub.name)")
                                        .tag(Category?.some(sub))
                                }
                            }
                        }
                    }

                    if selectedCategory == nil {
                        Text("A category is required.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}

// MARK: - Add Transaction

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SharingManager.self) private var sharingManager

    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]

    /// Only visible subcategories (not headers, not hidden) are shown in the category picker
    var categories: [Category] {
        allCategories.filter { !$0.isHeader && !$0.isHidden }
    }

    var preselectedAccount: Account?
    var preselectedCategory: Category?

    @State private var amountText = ""
    @State private var payee = ""
    @State private var memo = ""
    @State private var date = Date()
    @State private var type: TransactionType = .expense
    @State private var selectedAccount: Account?
    @State private var selectedTransferTo: Account?
    @State private var selectedCategory: Category?
    @State private var hasSetInitialAccount = false

    /// Whether this transaction should have a category
    var shouldHaveCategory: Bool {
        if type == .transfer {
            guard let from = selectedAccount, let to = selectedTransferTo else { return false }
            return from.isBudget != to.isBudget
        }
        return selectedAccount?.isBudget ?? false
    }

    var canSave: Bool {
        // Amount must be non-zero
        guard let amount = Decimal(string: amountText), amount > 0 else { return false }

        // Account is always required
        guard selectedAccount != nil else { return false }

        if type == .transfer {
            // Transfer needs both accounts, different from each other
            guard let to = selectedTransferTo,
                  selectedAccount?.persistentModelID != to.persistentModelID else { return false }
            // Cross-boundary transfer needs category
            if shouldHaveCategory && selectedCategory == nil { return false }
            // Payee NOT required for transfers
            return true
        }

        // Income/expense: payee required
        guard !payee.isEmpty else { return false }

        // Budget account: category required
        if shouldHaveCategory && selectedCategory == nil { return false }

        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                TransactionFormFields(
                    amountText: $amountText,
                    payee: $payee,
                    memo: $memo,
                    date: $date,
                    type: $type,
                    selectedAccount: $selectedAccount,
                    selectedTransferTo: $selectedTransferTo,
                    selectedCategory: $selectedCategory,
                    accounts: accounts,
                    categories: categories,
                    autoFocusAmount: true
                )
            }
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTransaction() }
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
                guard !hasSetInitialAccount else { return }
                hasSetInitialAccount = true
                if let preselected = preselectedAccount {
                    selectedAccount = preselected
                } else if accounts.count == 1 {
                    selectedAccount = accounts.first
                }
                if let preselected = preselectedCategory {
                    selectedCategory = preselected
                }
            }
            .onChange(of: selectedAccount) { _, newAccount in
                // Clear category when switching to a Tracking account
                if let account = newAccount, !account.isBudget, type != .transfer {
                    selectedCategory = nil
                }
            }
        }
    }

    private func saveTransaction() {
        guard let amount = Decimal(string: amountText) else { return }

        let finalPayee = type == .transfer && payee.isEmpty ? "Transfer" : payee

        let transaction = Transaction(
            amount: amount,
            payee: finalPayee,
            memo: memo,
            date: date,
            type: type
        )

        transaction.account = selectedAccount
        if type == .transfer {
            transaction.transferToAccount = selectedTransferTo
        }
        transaction.category = shouldHaveCategory ? selectedCategory : nil

        modelContext.insert(transaction)
        updatePayeeRecord(name: finalPayee, category: transaction.category)

        // Log activity for shared budgets
        if sharingManager.isShared {
            let categoryName = transaction.category?.name ?? ""
            let message: String
            if type == .transfer {
                message = "\(sharingManager.currentUserName) added a transfer of \(amountText)"
            } else {
                let categoryPart = categoryName.isEmpty ? "" : " to \(categoryName)"
                message = "\(sharingManager.currentUserName) added a \(amount) \(type.rawValue.lowercased())\(categoryPart)"
            }
            sharingManager.logActivity(
                message: message,
                type: .addedTransaction,
                context: modelContext
            )
        }

        dismiss()
    }

    private func updatePayeeRecord(name: String, category: Category?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "Transfer" else { return }

        let descriptor = FetchDescriptor<Payee>(predicate: #Predicate { $0.name == trimmed })
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.recordUsage(category: category)
        } else {
            let newPayee = Payee(name: trimmed, lastUsedCategory: category)
            modelContext.insert(newPayee)
        }
    }
}

// MARK: - Edit Transaction

struct EditTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SharingManager.self) private var sharingManager

    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]

    /// Only visible subcategories shown in picker; includes hidden category if already assigned
    var categories: [Category] {
        var visible = allCategories.filter { !$0.isHeader && !$0.isHidden }
        if let current = transaction.category, current.isHidden,
           !visible.contains(where: { $0.persistentModelID == current.persistentModelID }) {
            visible.append(current)
        }
        return visible
    }

    let transaction: Transaction

    @State private var amountText = ""
    @State private var payee = ""
    @State private var memo = ""
    @State private var date = Date()
    @State private var type: TransactionType = .expense
    @State private var selectedAccount: Account?
    @State private var selectedTransferTo: Account?
    @State private var selectedCategory: Category?
    @State private var hasLoaded = false
    @State private var showingDeleteConfirmation = false

    /// Whether this transaction should have a category
    var shouldHaveCategory: Bool {
        if type == .transfer {
            guard let from = selectedAccount, let to = selectedTransferTo else { return false }
            return from.isBudget != to.isBudget
        }
        return selectedAccount?.isBudget ?? false
    }

    var canSave: Bool {
        // Amount must be non-zero
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
                TransactionFormFields(
                    amountText: $amountText,
                    payee: $payee,
                    memo: $memo,
                    date: $date,
                    type: $type,
                    selectedAccount: $selectedAccount,
                    selectedTransferTo: $selectedTransferTo,
                    selectedCategory: $selectedCategory,
                    accounts: accounts,
                    categories: categories
                )

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Transaction")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { updateTransaction() }
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

                amountText = "\(transaction.amount)"
                payee = transaction.payee
                memo = transaction.memo
                date = transaction.date
                type = transaction.type

                selectedAccount = transaction.account
                selectedTransferTo = transaction.transferToAccount
                selectedCategory = transaction.category
            }
            .onChange(of: selectedAccount) { _, newAccount in
                // Clear category when switching to a Tracking account
                if let account = newAccount, !account.isBudget, type != .transfer {
                    selectedCategory = nil
                }
            }
            .confirmationDialog(
                "Delete Transaction?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if sharingManager.isShared {
                        sharingManager.logActivity(
                            message: "\(sharingManager.currentUserName) deleted \(transaction.payee)",
                            type: .deletedTransaction,
                            context: modelContext
                        )
                    }
                    modelContext.delete(transaction)
                    dismiss()
                }
            } message: {
                Text("This will update your account balance and budget. This cannot be undone.")
            }
        }
    }

    private func updateTransaction() {
        guard let amount = Decimal(string: amountText) else { return }

        let finalPayee = type == .transfer && payee.isEmpty ? "Transfer" : payee

        transaction.amount = amount
        transaction.payee = finalPayee
        transaction.memo = memo
        transaction.date = date
        transaction.type = type

        transaction.account = selectedAccount
        transaction.transferToAccount = type == .transfer ? selectedTransferTo : nil
        transaction.category = shouldHaveCategory ? selectedCategory : nil

        // Update payee record (skip generic "Transfer")
        let trimmed = finalPayee.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != "Transfer" {
            let descriptor = FetchDescriptor<Payee>(predicate: #Predicate { $0.name == trimmed })
            if let existing = try? modelContext.fetch(descriptor).first {
                existing.recordUsage(category: transaction.category)
            } else {
                let newPayee = Payee(name: trimmed, lastUsedCategory: transaction.category)
                modelContext.insert(newPayee)
            }
        }

        // Log activity for shared budgets
        if sharingManager.isShared {
            let message = "\(sharingManager.currentUserName) edited \(finalPayee) (\(amountText))"
            sharingManager.logActivity(
                message: message,
                type: .editedTransaction,
                context: modelContext
            )
        }

        dismiss()
    }
}

#Preview {
    NavigationStack {
        TransactionsView()
    }
    .modelContainer(for: [Transaction.self, Account.self, Category.self, Payee.self, RecurringTransaction.self, ActivityEntry.self], inMemory: true)
    .environment(SharingManager())
}
