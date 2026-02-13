import SwiftUI
import SwiftData

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query private var allBudgetMonths: [BudgetMonth]
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]

    @State private var selectedMonth: Date = {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }()

    /// Tracks which headers are expanded (true = open). All start open.
    @State private var expandedHeaders: Set<String> = []
    @State private var hasInitialisedExpanded = false

    /// Local cache of budgeted amounts keyed by category persistentModelID string.
    /// Updated immediately on save so the UI reflects changes without waiting for @Query.
    @State private var localBudgets: [String: Decimal] = [:]

    /// Local override for "To Budget" balance, set immediately on save.
    /// Nil means: use the persistent calculation from BudgetCalculator.
    @State private var localToBudget: Decimal? = nil

    /// Local cache of available balances keyed by category persistentModelID string.
    /// Updated immediately on save so the "Available" column reflects changes without waiting for @Query.
    @State private var localAvailable: [String: Decimal] = [:]
    @State private var showingSettings = false
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    // MARK: - Computed

    /// The system "To Budget" category
    var toBudgetCategory: Category? {
        allCategories.first { $0.isSystem && $0.name == DefaultCategories.toBudgetName }
    }

    var headerCategories: [Category] {
        allCategories
            .filter { $0.isHeader && !$0.isSystem }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Subcategories whose available balance is negative this month
    var overspentCategories: [(name: String, amount: Decimal)] {
        headerCategories.flatMap { $0.sortedChildren }
            .compactMap { cat in
                let key = "\(cat.persistentModelID)"
                let avail = localAvailable[key] ?? cat.available(through: selectedMonth)
                return avail < 0 ? (name: cat.name, amount: avail) : nil
            }
    }

    /// The BudgetMonth for the currently selected month (if it exists)
    var currentBudgetMonth: BudgetMonth? {
        let calendar = Calendar.current
        return allBudgetMonths.first(where: {
            calendar.isDate($0.month, equalTo: selectedMonth, toGranularity: .month)
        })
    }

    /// "To Budget" balance — uses local override if available, otherwise persistent calc
    func computeToBudget() -> Decimal {
        if let local = localToBudget {
            return local
        }
        guard let tbc = toBudgetCategory else { return Decimal.zero }
        return BudgetCalculator.toBudgetAvailable(
            through: selectedMonth,
            toBudgetCategory: tbc,
            accounts: accounts,
            context: modelContext
        )
    }

    // MARK: - Body

    var body: some View {
        let currentToBudget = computeToBudget()

        NavigationStack {
            VStack(spacing: 0) {
                monthSelector
                toBudgetBanner(currentToBudget)
                overspentWarnings

                if headerCategories.isEmpty {
                    emptyState
                } else {
                    categoryList
                }
            }
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ManageCategoriesView()
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onAppear {
                if !hasInitialisedExpanded {
                    hasInitialisedExpanded = true
                    for header in headerCategories {
                        expandedHeaders.insert(header.name)
                    }
                }
                syncLocalBudgets()
            }
            .onChange(of: selectedMonth) { _, _ in
                syncLocalBudgets()
            }
        }
    }

    // MARK: - Month Selector

    var monthSelector: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
            }
            Spacer()
            Text(selectedMonth, format: .dateTime.month(.wide).year())
                .font(.headline)
            Spacer()
            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.bold())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - "To Budget" Banner

    func toBudgetBanner(_ amount: Decimal) -> some View {
        let label: String
        let labelColor: Color
        let bgColor: Color

        if amount > 0 {
            label = "To Budget"
            labelColor = .green
            bgColor = .green.opacity(0.12)
        } else if amount == 0 {
            label = "All Money Budgeted"
            labelColor = .primary
            bgColor = .gray.opacity(0.08)
        } else {
            label = "Overbudgeted"
            labelColor = .red
            bgColor = .red.opacity(0.12)
        }

        return VStack(spacing: 4) {
            GBPText(amount: amount, font: .title2.bold())
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(labelColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(bgColor)
    }

    // MARK: - Overspent Warnings

    var overspentWarnings: some View {
        Group {
            if !overspentCategories.isEmpty {
                VStack(spacing: 0) {
                    ForEach(overspentCategories, id: \.name) { item in
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("\(item.name) is overspent by \(formatGBP(-item.amount, currencyCode: currencyCode))")
                                .font(.caption2)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.85))
                    }
                }
            }
        }
    }

    // MARK: - Category List

    var categoryList: some View {
        List {
            // Column headers
            HStack(spacing: 4) {
                Text("Category")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("Budgeted")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .frame(width: 76, alignment: .trailing)
                Text("Available")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .frame(width: 70, alignment: .trailing)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .padding(.bottom, -4)

            ForEach(headerCategories) { header in
                Section {
                    // Collapsible header row
                    Button {
                        withAnimation {
                            if expandedHeaders.contains(header.name) {
                                expandedHeaders.remove(header.name)
                            } else {
                                expandedHeaders.insert(header.name)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: expandedHeaders.contains(header.name) ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 12)

                            Text(header.name.uppercased())
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Spacer()

                            // Header budgeted total for this month
                            Text(formatGBP(headerBudgeted(header), currencyCode: currencyCode))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .trailing)

                            // Header available total (accent orange)
                            let avail = headerAvailable(header)
                            Text(formatGBP(avail, currencyCode: currencyCode))
                                .font(.caption)
                                .foregroundStyle(avail < 0 ? .red : Color.accentColor)
                                .frame(width: 70, alignment: .trailing)
                        }
                    }
                    .listRowBackground(Color(.secondarySystemGroupedBackground).opacity(0.5))
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                    // Subcategories (only shown when expanded)
                    if expandedHeaders.contains(header.name) {
                        ForEach(header.sortedChildren) { subcategory in
                            let catKey = "\(subcategory.persistentModelID)"
                            let budgeted = localBudgets[catKey] ?? Decimal.zero
                            let avail = localAvailable[catKey] ?? subcategory.available(through: selectedMonth)
                            BudgetCategoryRow(
                                category: subcategory,
                                month: selectedMonth,
                                budgetedAmount: budgeted,
                                available: avail,
                                onBudgetChanged: { newAmount in
                                    saveBudget(for: subcategory, amount: newAmount)
                                }
                            )
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(4)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No categories yet")
                .font(.headline)
            Text("Tap the gear icon to set up your budget categories.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Helpers

    func changeMonth(by offset: Int) {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: selectedMonth) {
            let comps = calendar.dateComponents([.year, .month], from: newMonth)
            selectedMonth = calendar.date(from: comps) ?? newMonth
        }
    }

    /// Sync local budgets dictionary from modelContext for the current month.
    /// Called on appear and when month changes.
    /// Uses direct FetchDescriptor to bypass stale @Query relationship caches.
    func syncLocalBudgets() {
        var newBudgets: [String: Decimal] = [:]

        let descriptor = FetchDescriptor<BudgetAllocation>()
        if let allAllocations = try? modelContext.fetch(descriptor) {
            let calendar = Calendar.current
            for alloc in allAllocations {
                guard let allocMonth = alloc.budgetMonth?.month else { continue }
                guard calendar.isDate(allocMonth, equalTo: selectedMonth, toGranularity: .month) else { continue }
                if let cat = alloc.category {
                    newBudgets["\(cat.persistentModelID)"] = alloc.budgeted
                }
            }
        }
        localBudgets = newBudgets
        // Clear local overrides — let persistent calc take over
        localToBudget = nil
        localAvailable = [:]
    }

    func budgetedAmount(for category: Category) -> Decimal {
        let key = "\(category.persistentModelID)"
        return localBudgets[key] ?? Decimal.zero
    }

    func headerBudgeted(_ header: Category) -> Decimal {
        header.sortedChildren.reduce(Decimal.zero) { $0 + budgetedAmount(for: $1) }
    }

    func headerAvailable(_ header: Category) -> Decimal {
        header.sortedChildren.reduce(Decimal.zero) { sum, child in
            let key = "\(child.persistentModelID)"
            return sum + (localAvailable[key] ?? child.available(through: selectedMonth))
        }
    }

    /// Save a budget amount inline.
    /// 1. Updates localBudgets and localToBudget for immediate UI response
    /// 2. Persists the BudgetAllocation to SwiftData
    func saveBudget(for category: Category, amount: Decimal) {
        let calendar = Calendar.current
        let catKey = "\(category.persistentModelID)"

        // Compute the delta (how much more or less we're budgeting vs before)
        let previousAmount = localBudgets[catKey] ?? Decimal.zero
        let delta = amount - previousAmount

        // 1. Update local state FIRST (immediate UI response)
        localBudgets[catKey] = amount

        // Update local "Available" — budgeting more increases available by the delta
        let currentAvail = localAvailable[catKey] ?? category.available(through: selectedMonth)
        localAvailable[catKey] = currentAvail + delta

        // Update local "To Budget" — subtract the delta (budgeting moves money OUT of To Budget)
        let currentTB = localToBudget ?? computePersistentToBudget()
        localToBudget = currentTB - delta

        // 2. Persist to SwiftData — fetch BudgetMonth directly from modelContext
        let bmDescriptor = FetchDescriptor<BudgetMonth>()
        let allBMs = (try? modelContext.fetch(bmDescriptor)) ?? []
        var bm = allBMs.first(where: {
            calendar.isDate($0.month, equalTo: selectedMonth, toGranularity: .month)
        })
        if bm == nil {
            let newBM = BudgetMonth(month: selectedMonth)
            modelContext.insert(newBM)
            bm = newBM
        }

        // Find or create allocation — fetch directly from modelContext for fresh data
        let catID = category.persistentModelID
        guard let budgetMonth = bm else { return }
        let allocDescriptor = FetchDescriptor<BudgetAllocation>()
        let allAllocations = (try? modelContext.fetch(allocDescriptor)) ?? []
        let existingAlloc = allAllocations.first(where: {
            $0.category?.persistentModelID == catID &&
            $0.budgetMonth?.persistentModelID == budgetMonth.persistentModelID
        })

        if let existing = existingAlloc {
            existing.budgeted = amount
        } else {
            let allocation = BudgetAllocation(budgeted: amount)
            allocation.category = category
            allocation.budgetMonth = bm
            modelContext.insert(allocation)
        }

        try? modelContext.save()
    }

    /// Compute "To Budget" from persistent data (no local overrides)
    private func computePersistentToBudget() -> Decimal {
        guard let tbc = toBudgetCategory else { return Decimal.zero }
        return BudgetCalculator.toBudgetAvailable(
            through: selectedMonth,
            toBudgetCategory: tbc,
            accounts: accounts,
            context: modelContext
        )
    }
}

// MARK: - Budget Category Row with inline editing

struct BudgetCategoryRow: View {
    let category: Category
    let month: Date
    let budgetedAmount: Decimal
    let available: Decimal
    let onBudgetChanged: (Decimal) -> Void

    /// Raw digits string — user types "1536", we store "1536" and display £15.36
    @State private var rawDigits: String = ""
    @State private var previousDigits: String = ""  // backup for cancel-on-blur
    @State private var hasLoaded: Bool = false
    @State private var hasTyped: Bool = false  // tracks whether user typed anything while focused
    @FocusState private var isFocused: Bool
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    /// Pence value from raw digits
    private var amountInPence: Int {
        Int(rawDigits) ?? 0
    }

    /// Formatted display using selected currency
    private var displayString: String {
        formatPence(amountInPence, currencyCode: currencyCode)
    }

    /// Convert minor units to Decimal major units for saving
    private var decimalAmount: Decimal {
        let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
        return Decimal(amountInPence) / Decimal(currency.minorUnitMultiplier)
    }

    var body: some View {
        HStack(spacing: 4) {
            // Category name (left)
            Text(category.name)
                .font(.footnote)
                .lineLimit(1)

            Spacer()

            // Budgeted this month (middle, editable — pence-based ATM entry)
            ZStack {
                // Hidden text field bound to rawDigits
                TextField("", text: $rawDigits)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .opacity(0.01)
                    .frame(width: 70, height: 24)
                    .onChange(of: isFocused) { _, focused in
                        if focused {
                            // Save current value before clearing, so we can restore on cancel
                            previousDigits = rawDigits
                            hasTyped = false
                            rawDigits = ""
                        } else if !focused {
                            // If user typed nothing (didn't press any key), restore previous value
                            if !hasTyped {
                                rawDigits = previousDigits
                            } else {
                                // User typed something (even if it was "0" which stripped to "")
                                onBudgetChanged(decimalAmount)
                            }
                        }
                    }
                    .onChange(of: rawDigits) { _, newValue in
                        // Mark that the user has typed if we're focused and digits came in
                        if isFocused {
                            let digits = newValue.filter { $0.isNumber }
                            if !digits.isEmpty {
                                hasTyped = true
                            }
                        }
                        // Strip non-digits, leading zeros, cap at 8 digits
                        let digits = newValue.filter { $0.isNumber }
                        let trimmed = String(digits.drop(while: { $0 == "0" }))
                        let capped = String(trimmed.prefix(8))
                        if rawDigits != capped {
                            rawDigits = capped
                        }
                    }

                // Visible display
                Text(displayString)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70, alignment: .trailing)
                    .contentTransition(.numericText())
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 1.5)
                    )
            )

            // Available balance (right, accent orange)
            GBPText(amount: available, font: .footnote.bold(), accentPositive: true)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 1)
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            if budgetedAmount != .zero {
                let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
                let multiplier = Decimal(currency.minorUnitMultiplier)
                let minorUnits = NSDecimalNumber(decimal: budgetedAmount * multiplier).intValue
                rawDigits = minorUnits > 0 ? "\(minorUnits)" : ""
            }
        }
        .onChange(of: budgetedAmount) { _, newVal in
            if !isFocused {
                let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
                let multiplier = Decimal(currency.minorUnitMultiplier)
                let minorUnits = NSDecimalNumber(decimal: newVal * multiplier).intValue
                rawDigits = minorUnits > 0 ? "\(minorUnits)" : ""
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BudgetView()
        .modelContainer(for: [
            Account.self,
            Transaction.self,
            Category.self,
            BudgetMonth.self,
            BudgetAllocation.self,
            SavingsGoal.self,
            Payee.self,
        ], inMemory: true)
}
