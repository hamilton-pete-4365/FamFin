import SwiftUI
import SwiftData

// MARK: - Shared Form Fields for Recurring Transactions

struct RecurringTransactionFormFields: View {
    @Binding var amountText: String
    @Binding var payee: String
    @Binding var memo: String
    @Binding var type: TransactionType
    @Binding var frequency: RecurrenceFrequency
    @Binding var startDate: Date
    @Binding var hasEndDate: Bool
    @Binding var endDate: Date
    @Binding var selectedAccount: Account?
    @Binding var selectedTransferTo: Account?
    @Binding var selectedCategory: Category?

    let accounts: [Account]
    let categories: [Category]

    @State private var rawDigits: String = ""
    @State private var hasLoadedAmount = false
    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false
    @FocusState private var amountFocused: Bool
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var amountInPence: Int {
        Int(rawDigits) ?? 0
    }

    private var amountDisplayString: String {
        let base = formatPence(amountInPence, currencyCode: currencyCode)
        switch type {
        case .expense: return "-\(base)"
        case .income: return "+\(base)"
        case .transfer: return base
        }
    }

    private var amountColor: Color {
        guard amountInPence > 0 else { return .secondary }
        switch type {
        case .expense: return .red
        case .income: return .green
        case .transfer: return .primary
        }
    }

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

    var transferNeedsCategory: Bool {
        guard type == .transfer,
              let from = selectedAccount,
              let to = selectedTransferTo else { return false }
        return from.isBudget != to.isBudget
    }

    var selectedAccountIsBudget: Bool {
        selectedAccount?.isBudget ?? false
    }

    var showCategory: Bool {
        if type == .transfer { return transferNeedsCategory }
        return selectedAccountIsBudget
    }

    var budgetAccounts: [Account] {
        accounts.filter { $0.isBudget }
    }

    var trackingAccounts: [Account] {
        accounts.filter { !$0.isBudget }
    }

    var toBudgetCategory: Category? {
        categories.first { $0.isSystem && $0.name == DefaultCategories.toBudgetName }
    }

    var groupedCategories: [CategoryGroup] {
        var seen = Set<String>()
        var headerOrder: [(name: String, parent: Category)] = []
        for category in categories where !category.isSystem {
            if let parent = category.parent, !seen.contains(parent.name) {
                seen.insert(parent.name)
                headerOrder.append((parent.name, parent))
            }
        }
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
        let orphans = categories
            .filter { !$0.isSystem && $0.parent == nil && !$0.isHeader }
            .sorted { $0.sortOrder < $1.sortOrder }
        if !orphans.isEmpty {
            result.append(CategoryGroup(headerName: "Other", subcategories: orphans))
        }
        return result
    }

    var body: some View {
        // Amount
        Section {
            ZStack {
                TextField("", text: $rawDigits)
                    .keyboardType(.numberPad)
                    .focused($amountFocused)
                    .opacity(0.01)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
                    .onChange(of: rawDigits) { _, newValue in
                        let digits = newValue.filter { $0.isNumber }
                        let trimmed = String(digits.drop(while: { $0 == "0" }))
                        let capped = String(trimmed.prefix(8))
                        if rawDigits != capped {
                            rawDigits = capped
                        }
                        syncAmountText()
                    }

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
            if !hasLoadedAmount {
                hasLoadedAmount = true
                if let decimal = Decimal(string: amountText), decimal > 0 {
                    let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
                    let multiplier = Decimal(currency.minorUnitMultiplier)
                    let minorUnits = NSDecimalNumber(decimal: decimal * multiplier).intValue
                    rawDigits = minorUnits > 0 ? "\(minorUnits)" : ""
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

        // Details
        Section("Details") {
            PayeeSuggestionField(
                payeeText: $payee,
                suggestedCategory: $selectedCategory,
                isOptional: type == .transfer
            )
            TextField("Memo (optional)", text: $memo)
        }

        // Recurrence schedule
        Section("Schedule") {
            Picker("Frequency", selection: $frequency) {
                ForEach(RecurrenceFrequency.allCases) { freq in
                    Text(freq.displayName).tag(freq)
                }
            }

            // Start date
            Button {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                withAnimation(reduceMotion ? nil : .default) { showStartDatePicker.toggle() }
            } label: {
                HStack {
                    Text("Start Date")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(startDate, format: .dateTime.day().month().year())
                        .foregroundStyle(showStartDatePicker ? Color.accentColor : .secondary)
                }
            }

            if showStartDatePicker {
                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .onChange(of: startDate) { _, _ in
                        withAnimation(reduceMotion ? nil : .default) { showStartDatePicker = false }
                    }
            }

            // Optional end date
            Toggle("End Date", isOn: reduceMotion ? $hasEndDate : $hasEndDate.animation())

            if hasEndDate {
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    withAnimation(reduceMotion ? nil : .default) { showEndDatePicker.toggle() }
                } label: {
                    HStack {
                        Text("Ends On")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(endDate, format: .dateTime.day().month().year())
                            .foregroundStyle(showEndDatePicker ? Color.accentColor : .secondary)
                    }
                }

                if showEndDatePicker {
                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .onChange(of: endDate) { _, _ in
                            withAnimation(reduceMotion ? nil : .default) { showEndDatePicker = false }
                        }
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

        // Category
        if showCategory {
            Section("Category") {
                if categories.isEmpty {
                    Text("No categories yet")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Category", selection: $selectedCategory) {
                        if let toBudget = toBudgetCategory {
                            Text("\u{1F4B0} To Budget").tag(Category?.some(toBudget))
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

// MARK: - Add Recurring Transaction

struct AddRecurringTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]

    var categories: [Category] {
        allCategories.filter { !$0.isHeader }
    }

    @State private var amountText = ""
    @State private var payee = ""
    @State private var memo = ""
    @State private var type: TransactionType = .expense
    @State private var frequency: RecurrenceFrequency = .monthly
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var generateFirstTransaction = true
    @State private var selectedAccount: Account?
    @State private var selectedTransferTo: Account?
    @State private var selectedCategory: Category?
    @State private var hasSetInitialAccount = false

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
                    Toggle("Create first transaction now", isOn: $generateFirstTransaction)
                }
            }
            .navigationTitle("New Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRule() }
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
                if accounts.count == 1 {
                    selectedAccount = accounts.first
                }
            }
            .onChange(of: selectedAccount) { _, newAccount in
                if let account = newAccount, !account.isBudget, type != .transfer {
                    selectedCategory = nil
                }
            }
        }
    }

    private func saveRule() {
        guard let amount = Decimal(string: amountText) else { return }

        let finalPayee = type == .transfer && payee.isEmpty ? "Transfer" : payee

        let rule = RecurringTransaction(
            amount: amount,
            payee: finalPayee,
            memo: memo,
            type: type,
            frequency: frequency,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil
        )

        rule.account = selectedAccount
        rule.category = shouldHaveCategory ? selectedCategory : nil

        if type == .transfer {
            rule.transferToAccount = selectedTransferTo
        }

        // If start date is in the future, nextOccurrence is already set to startDate.
        // If start date is today or in the past and we're generating the first transaction,
        // advance nextOccurrence to the next recurrence.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: startDate)

        if generateFirstTransaction && start <= today {
            // Create the first transaction immediately
            let transaction = Transaction(
                amount: amount,
                payee: finalPayee,
                memo: memo,
                date: startDate,
                type: type,
                isAutoGenerated: true
            )
            transaction.account = selectedAccount
            transaction.category = shouldHaveCategory ? selectedCategory : nil
            if type == .transfer {
                transaction.transferToAccount = selectedTransferTo
            }
            modelContext.insert(transaction)

            // Advance nextOccurrence past today
            var next = frequency.nextDate(after: start)
            while calendar.startOfDay(for: next) <= today {
                // Create transactions for any missed occurrences
                let missedTransaction = Transaction(
                    amount: amount,
                    payee: finalPayee,
                    memo: memo,
                    date: next,
                    type: type,
                    isAutoGenerated: true
                )
                missedTransaction.account = selectedAccount
                missedTransaction.category = shouldHaveCategory ? selectedCategory : nil
                if type == .transfer {
                    missedTransaction.transferToAccount = selectedTransferTo
                }
                modelContext.insert(missedTransaction)

                next = frequency.nextDate(after: next)
            }
            rule.nextOccurrence = next
        }

        modelContext.insert(rule)
        dismiss()
    }
}
