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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    @State private var showingAddTransaction = false
    @State private var filterAccountIDs: Set<PersistentIdentifier> = []
    @State private var editingTransaction: Transaction?
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var transactionToDelete: Transaction?
    @State private var showMonthPicker = false
    @State private var showFilterPopover = false
    @Environment(SelectedMonthStore.self) private var monthStore

    /// Reads from the shared store so both Budget and Transactions stay in sync.
    private var selectedMonth: Date { monthStore.selectedMonth }

    // MARK: - Computed

    var filterAccounts: [Account] {
        accounts.filter { filterAccountIDs.contains($0.persistentModelID) }
    }

    /// Whether an account filter or search is active (drives the toolbar icon fill state).
    var hasActiveFilters: Bool {
        !filterAccountIDs.isEmpty || isSearching
    }

    /// Whether the selected month is the current calendar month.
    var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    var budgetAccounts: [Account] {
        accounts.filter { $0.isBudget }
    }

    var trackingAccounts: [Account] {
        accounts.filter { !$0.isBudget }
    }

    /// Step 1: filter by selected month
    var monthFiltered: [Transaction] {
        let calendar = Calendar.current
        return allTransactions.filter {
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    /// Step 2: filter by selected accounts
    var accountFiltered: [Transaction] {
        guard !filterAccountIDs.isEmpty else { return monthFiltered }
        return monthFiltered.filter {
            if let id = $0.account?.persistentModelID, filterAccountIDs.contains(id) { return true }
            if let id = $0.transferToAccount?.persistentModelID, filterAccountIDs.contains(id) { return true }
            return false
        }
    }

    /// Step 3: filter by search text (payee, memo, category name)
    var filteredTransactions: [Transaction] {
        guard !searchText.isEmpty else { return accountFiltered }
        return accountFiltered.filter { transaction in
            transaction.payee.localizedStandardContains(searchText) ||
            transaction.memo.localizedStandardContains(searchText) ||
            (transaction.category?.name.localizedStandardContains(searchText) ?? false)
        }
    }

    /// Step 4: group by calendar day
    var groupedTransactions: [TransactionGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { TransactionGroup(date: $0.key, transactions: $0.value.sorted { a, b in
                a.signedAmount < b.signedAmount
            }) }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            monthSelector

            // Filter banners (visible when account filter is active)
            accountFilterBanners

            // Search bar (visible when search is active)
            if isSearching {
                searchBar
            }

            // Persistent separator between header area and scrollable content
            Color(.opaqueSeparator)
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)

            // Transaction list
            if groupedTransactions.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                transactionList
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50, coordinateSpace: .local)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        if value.translation.width < 0 {
                            changeMonth(by: 1)
                        } else {
                            changeMonth(by: -1)
                        }
                    }
                }
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ProfileButton()
            }
            ToolbarSpacer(.fixed, placement: .topBarLeading)
            ToolbarItem(placement: .topBarLeading) {
                Button("Search", systemImage: "magnifyingglass") {
                    isSearching.toggle()
                    if !isSearching {
                        searchText = ""
                        isSearchFieldFocused = false
                    }
                }
                .foregroundStyle(isSearching ? Color.accentColor : .secondary)
            }
            ToolbarItem(placement: .principal) {
                Text("Transactions")
                    .font(.headline)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Add Transaction", systemImage: "plus") {
                    showingAddTransaction = true
                }
            }
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) {
                filterMenu
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView(
                preselectedAccount: filterAccounts.count == 1 ? filterAccounts.first : nil,
                defaultDate: isCurrentMonth ? nil : lastDayOfSelectedMonth
            )
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

    // MARK: - Month Selector

    var monthSelector: some View {
        @Bindable var store = monthStore
        return HStack {
            Button("Previous month", systemImage: "chevron.left") {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    changeMonth(by: -1)
                }
            }
            .labelStyle(.iconOnly)
            .font(.title3.bold())
            .accessibilityHint("Double tap to go to the previous month")

            Spacer()

            Button {
                showMonthPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(selectedMonth, format: .dateTime.month(.wide).year())
                        .font(.headline)
                    Image(systemName: "chevron.down")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint("Double tap to choose a different month")
            .popover(isPresented: $showMonthPicker) {
                MonthYearPicker(selectedMonth: $store.selectedMonth)
                    .presentationCompactAdaptation(.popover)
            }

            Spacer()

            Button("Next month", systemImage: "chevron.right") {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    changeMonth(by: 1)
                }
            }
            .labelStyle(.iconOnly)
            .font(.title3.bold())
            .accessibilityHint("Double tap to go to the next month")
        }
        .overlay {
            if !isCurrentMonth {
                HStack {
                    if selectedMonth < Date() {
                        Spacer()
                    }
                    todayButton
                    if selectedMonth > Date() {
                        Spacer()
                    }
                }
                .padding(.horizontal, 28)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var todayButton: some View {
        Button("Today") {
            goToToday()
        }
        .font(.caption)
        .bold()
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.15))
        .clipShape(.rect(cornerRadius: 6))
        .buttonStyle(.plain)
        .accessibilityHint("Double tap to return to the current month")
    }

    // MARK: - Filter Banners

    @ViewBuilder
    private var accountFilterBanners: some View {
        let selected = filterAccounts
        if !selected.isEmpty {
            VStack(spacing: 8) {
                if selected.count <= 3 {
                    ForEach(selected) { account in
                        filterBanner(
                            text: account.name,
                            accessibilityLabel: "Filtered by \(account.name)"
                        ) {
                            withAnimation { _ = filterAccountIDs.remove(account.persistentModelID) }
                        }
                    }
                } else {
                    filterBanner(
                        text: "Filtering \(selected.count) of \(accounts.count) accounts",
                        accessibilityLabel: "Filtering \(selected.count) of \(accounts.count) accounts"
                    ) {
                        withAnimation { filterAccountIDs.removeAll() }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }

    private func filterBanner(text: String, accessibilityLabel: String, onDismiss: @escaping () -> Void) -> some View {
        HStack {
            Text(text)
                .font(.subheadline)
                .bold()
            Spacer()
            Button("Remove filter", systemImage: "xmark.circle.fill") {
                onDismiss()
            }
            .labelStyle(.iconOnly)
            .font(.subheadline)
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.accentColor.opacity(0.15))
        .clipShape(.rect(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to remove filter")
    }

    // MARK: - Search Bar

    @FocusState private var isSearchFieldFocused: Bool

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                TextField("Search payee, memo, or category", text: $searchText)
                    .font(.body)
                    .focused($isSearchFieldFocused)
                    .submitLabel(.search)
                if !searchText.isEmpty {
                    Button("Clear", systemImage: "xmark.circle.fill") {
                        searchText = ""
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemFill))
            .clipShape(.rect(cornerRadius: 10))

            Button("Cancel") {
                searchText = ""
                isSearchFieldFocused = false
                isSearching = false
            }
            .font(.body)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .onAppear {
            isSearchFieldFocused = true
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Filter Menu

    private var filterMenu: some View {
        Button("Filter", systemImage: hasActiveFilters
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"
        ) {
            showFilterPopover.toggle()
        }
        .popover(isPresented: $showFilterPopover, arrowEdge: .top) {
            filterPopoverContent
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("Account filter")
        .accessibilityHint(hasActiveFilters ? "Filter is active" : "Double tap to filter by account")
    }

    private var filterPopoverContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            filterRow(
                label: "All Accounts",
                isSelected: filterAccountIDs.isEmpty
            ) {
                withAnimation { filterAccountIDs.removeAll() }
            }

            if !budgetAccounts.isEmpty {
                sectionHeader("Budget Accounts")
                ForEach(budgetAccounts) { account in
                    accountToggleRow(account)
                }
            }

            if !trackingAccounts.isEmpty {
                sectionHeader("Tracking Accounts")
                ForEach(trackingAccounts) { account in
                    accountToggleRow(account)
                }
            }
        }
        .padding(.vertical, 8)
        .frame(minWidth: 240)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private func accountToggleRow(_ account: Account) -> some View {
        let isSelected = filterAccountIDs.contains(account.persistentModelID)
        return filterRow(label: account.name, isSelected: isSelected) {
            withAnimation {
                if isSelected {
                    filterAccountIDs.remove(account.persistentModelID)
                } else {
                    filterAccountIDs.insert(account.persistentModelID)
                }
            }
        }
    }

    private func filterRow(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Transaction List

    private var transactionList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Color.clear
                        .frame(height: 0)
                        .id("transactionListTop")

                    ForEach(groupedTransactions.enumerated(), id: \.element.id) { index, group in
                    Section {
                        ForEach(group.transactions) { transaction in
                            Button {
                                editingTransaction = transaction
                            } label: {
                                TransactionRow(
                                    transaction: transaction
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    transactionToDelete = transaction
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }

                            // Row separator
                            Divider()
                        }
                    } header: {
                        dayHeader(for: group.date)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: selectedMonth) {
            proxy.scrollTo("transactionListTop", anchor: .top)
        }
        }
    }

    /// Sticky day section header styled to match Budget's category group headers.
    private func dayHeader(for date: Date) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(date, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Bottom separator
            Divider()
        }
        .background(Color(.secondarySystemBackground))
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if !filterAccountIDs.isEmpty {
            ContentUnavailableView(
                "No Transactions",
                systemImage: "list.bullet.rectangle.fill",
                description: Text("No transactions for the selected \(filterAccountIDs.count == 1 ? "account" : "accounts") in \(selectedMonth, format: .dateTime.month(.wide).year()).")
            )
        } else {
            ContentUnavailableView(
                "No Transactions",
                systemImage: "list.bullet.rectangle.fill",
                description: Text("No transactions in \(selectedMonth, format: .dateTime.month(.wide).year()). Tap + to add one.")
            )
        }
    }

    // MARK: - Helpers

    /// The last day of the currently selected month (e.g. 28 Feb, 31 Mar).
    private var lastDayOfSelectedMonth: Date {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: selectedMonth),
              let lastDay = calendar.date(bySetting: .day, value: range.upperBound - 1, of: selectedMonth)
        else { return selectedMonth }
        return lastDay
    }

    private func changeMonth(by offset: Int) {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: selectedMonth) {
            let comps = calendar.dateComponents([.year, .month], from: newMonth)
            monthStore.selectedMonth = calendar.date(from: comps) ?? newMonth
        }
    }

    private func goToToday() {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: Date())
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            monthStore.selectedMonth = calendar.date(from: comps) ?? Date()
        }
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
        HStack(spacing: 8) {
            if transaction.type == .transfer {
                Text("↔️")
                    .font(.title3)
                    .accessibilityHidden(true)
            } else if let category = transaction.category {
                Text(category.emoji)
                    .font(.title3)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "banknote")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayPayee)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if transaction.type == .transfer {
                        if let from = transaction.account, let to = transaction.transferToAccount {
                            Text("\(from.name) → \(to.name)")
                        }
                    } else {
                        if showAccount, let account = transaction.account {
                            Text(account.name)
                        }
                        if let category = transaction.category {
                            if showAccount && transaction.account != nil {
                                Text("·")
                            }
                            Text(category.name)
                        }
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            transactionAmount
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to edit transaction")
    }

    @ViewBuilder
    private var transactionAmount: some View {
        if transaction.type == .transfer {
            if let viewing = viewingAccount {
                if transaction.transferToAccount?.persistentModelID == viewing.persistentModelID {
                    TransactionAmountText(amount: transaction.amount, type: .income, font: .subheadline.bold())
                } else {
                    TransactionAmountText(amount: transaction.amount, type: .expense, font: .subheadline.bold())
                }
            } else {
                TransactionAmountText(amount: transaction.amount, type: .transfer, font: .subheadline.bold())
            }
        } else {
            TransactionAmountText(amount: transaction.amount, type: transaction.type, font: .subheadline.bold())
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TransactionsView()
    }
    .environment(SelectedMonthStore())
    .modelContainer(for: [Transaction.self, Account.self, Category.self, Payee.self], inMemory: true)
}
