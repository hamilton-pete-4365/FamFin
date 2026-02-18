import SwiftUI
import SwiftData

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Environment(SharingManager.self) private var sharingManager
    @Environment(ReviewPromptManager.self) private var reviewPromptManager
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query private var allBudgetMonths: [BudgetMonth]
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @Query private var allTransactions: [Transaction]
    @Query private var allGoals: [SavingsGoal]

    /// Lightweight fingerprint that changes when transactions are added, deleted, or edited.
    /// Watches count, total amount, and categorised count so budget recalculates on edits.
    private var transactionFingerprint: String {
        let count = allTransactions.count
        let total = allTransactions.reduce(Decimal.zero) { $0 + $1.amount }
        let categorised = allTransactions.filter { $0.category != nil }.count
        return "\(count)-\(total)-\(categorised)"
    }

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
    @State private var overspentExpanded = false
    @State private var detailCategory: Category? = nil
    @State private var navigationPath = NavigationPath()
    /// The category currently being edited (keyboard is up)
    @State private var focusedCategory: Category? = nil
    /// Set by keyboard toolbar hint buttons; consumed by the focused row
    @State private var pendingHintAmount: Decimal? = nil
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
    var overspentCategories: [(id: String, name: String, amount: Decimal)] {
        headerCategories.flatMap { $0.sortedChildren }
            .compactMap { cat in
                let key = "\(cat.persistentModelID)"
                let avail = localAvailable[key] ?? cat.available(through: selectedMonth)
                return avail < 0 ? (id: key, name: cat.name, amount: avail) : nil
            }
    }

    /// The BudgetMonth for the currently selected month (if it exists)
    var currentBudgetMonth: BudgetMonth? {
        let calendar = Calendar.current
        return allBudgetMonths.first(where: {
            calendar.isDate($0.month, equalTo: selectedMonth, toGranularity: .month)
        })
    }

    /// Historic "To Budget" balance through selected month (ignores future budgeting).
    /// Uses local override if available, otherwise persistent calc.
    func computeHistoricToBudget() -> Decimal {
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

    /// Total budgeted in months after the selected month.
    func computeFutureBudgeted() -> Decimal {
        BudgetCalculator.futureBudgeted(after: selectedMonth, context: modelContext)
    }

    // MARK: - Body

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let historicToBudget = computeHistoricToBudget()
        let futureBudgeted = computeFutureBudgeted()

        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                monthSelector
                toBudgetBanner(historic: historicToBudget, future: futureBudgeted)
                overspentWarnings
                keyboardHintBar

                if headerCategories.isEmpty {
                    emptyState
                } else {
                    columnHeaders
                    categoryList
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: focusedCategory?.persistentModelID)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Settings", systemImage: "slider.horizontal.3") {
                        showingSettings = true
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Budget")
                        .font(.headline)
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ManageCategoriesView()
                    } label: {
                        Label("Categories", systemImage: "gear")
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
            .sheet(item: $detailCategory) { category in
                CategoryDetailSheet(category: category, month: selectedMonth, onNavigateToGoal: { goalID in
                    navigationPath.append(goalID)
                })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .navigationDestination(for: PersistentIdentifier.self) { goalID in
                GoalDetailView(goalID: goalID)
            }
            .onAppear {
                if !hasInitialisedExpanded {
                    hasInitialisedExpanded = true
                    for header in headerCategories {
                        expandedHeaders.insert("\(header.persistentModelID)")
                    }
                }
                syncLocalBudgets()
            }
            .onChange(of: selectedMonth) { _, _ in
                syncLocalBudgets()
            }
            .onChange(of: transactionFingerprint) { _, _ in
                // Transaction added/deleted/edited — clear local caches so Available recalculates
                localAvailable = [:]
                localToBudget = nil
            }
        }
    }

    // MARK: - Month Selector

    var monthSelector: some View {
        HStack {
            Button("Previous month", systemImage: "chevron.left") {
                changeMonth(by: -1)
            }
            .labelStyle(.iconOnly)
            .font(.title3.bold())
            .accessibilityHint("Double tap to go to the previous month")
            Spacer()
            Text(selectedMonth, format: .dateTime.month(.wide).year())
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button("Next month", systemImage: "chevron.right") {
                changeMonth(by: 1)
            }
            .labelStyle(.iconOnly)
            .font(.title3.bold())
            .accessibilityHint("Double tap to go to the next month")
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - "To Budget" Banner

    /// Banner logic:
    /// - If historic To Budget is negative → Overbudgeted (warning amber)
    /// - If historic To Budget is positive and not absorbed by future → To Budget (green)
    /// - Otherwise (zero or fully absorbed) → hidden
    @ViewBuilder
    func toBudgetBanner(historic: Decimal, future: Decimal) -> some View {
        if historic < 0 {
            // Overbudgeted this month
            bannerContent(amount: historic, label: "Overbudgeted", labelColor: Color("WarningColor"), bgColor: Color("WarningColor").opacity(0.12))
        } else if historic > 0 {
            let remainder = historic - future
            if remainder > 0 {
                // Genuinely unbudgeted money remains
                bannerContent(amount: remainder, label: "To Budget", labelColor: .green, bgColor: .green.opacity(0.12))
            }
            // else: future absorbs it — hide banner
        }
        // else: exactly zero — hide banner
    }

    private func bannerContent(amount: Decimal, label: String, labelColor: Color, bgColor: Color) -> some View {
        VStack(spacing: 4) {
            GBPText(amount: amount, font: .title2.bold())
            Text(label)
                .font(.subheadline)
                .bold()
                .foregroundStyle(labelColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(bgColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(formatGBP(amount, currencyCode: currencyCode))")
    }

    // MARK: - Overspent Warnings

    var overspentWarnings: some View {
        Group {
            if !overspentCategories.isEmpty && focusedCategory == nil {
                let totalOverspent = overspentCategories.reduce(Decimal.zero) { $0 + $1.amount }
                let count = overspentCategories.count
                VStack(spacing: 0) {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            overspentExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text("\(count) \(count == 1 ? "category" : "categories") overspent by \(formatGBP(-totalOverspent, currencyCode: currencyCode))")
                                .font(.caption)
                                .bold()
                            Spacer()
                            Image(systemName: overspentExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .accessibilityLabel("Warning: \(count) \(count == 1 ? "category" : "categories") overspent by \(formatGBP(-totalOverspent, currencyCode: currencyCode))")
                    .accessibilityHint(overspentExpanded ? "Double tap to collapse details" : "Double tap to expand details")
                    .background(Color("WarningColor"))

                    if overspentExpanded {
                        VStack(spacing: 0) {
                            ForEach(overspentCategories, id: \.id) { item in
                                HStack(spacing: 8) {
                                    Text(item.name)
                                        .font(.caption)
                                    Spacer()
                                    Text(formatGBP(-item.amount, currencyCode: currencyCode))
                                        .font(.caption)
                                        .monospacedDigit()
                                        .bold()
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(item.name) overspent by \(formatGBP(-item.amount, currencyCode: currencyCode))")
                            }
                        }
                        .background(Color("WarningColor").opacity(0.85))
                    }
                }
            }
        }
    }

    // MARK: - Column Headers (pinned outside List)

    var columnHeaders: some View {
        HStack(spacing: 4) {
            Text("Category")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
            Text("Budgeted")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .frame(width: 88, alignment: .trailing)
            Text("Available")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .frame(width: 76, alignment: .trailing)
        }
        .padding(.leading, 32)
        .padding(.trailing, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(.systemGroupedBackground))
        .accessibilityHidden(true)
    }

    // MARK: - Category List

    var categoryList: some View {
        List {
            ForEach(headerCategories) { header in
                Section {
                    // Collapsible header row
                    Button {
                        withAnimation(reduceMotion ? nil : .default) {
                            let headerKey = "\(header.persistentModelID)"
                            if expandedHeaders.contains(headerKey) {
                                expandedHeaders.remove(headerKey)
                            } else {
                                expandedHeaders.insert(headerKey)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: expandedHeaders.contains("\(header.persistentModelID)") ? "chevron.down" : "chevron.right")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 16)

                            Text(header.name.uppercased())
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Spacer()

                            // Header budgeted total for this month
                            Text(formatGBP(headerBudgeted(header), currencyCode: currencyCode))
                                .font(.subheadline)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 88, alignment: .trailing)

                            // Header available total
                            let avail = headerAvailable(header)
                            Text(formatGBP(avail, currencyCode: currencyCode))
                                .font(.subheadline)
                                .monospacedDigit()
                                .foregroundStyle(avail < 0 ? .red : Color.accentColor)
                                .frame(width: 76, alignment: .trailing)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel("\(header.name), budgeted \(formatGBP(headerBudgeted(header), currencyCode: currencyCode)), available \(formatGBP(headerAvailable(header), currencyCode: currencyCode))\(headerAvailable(header) < 0 ? ", overspent" : "")")
                    .accessibilityHint(expandedHeaders.contains("\(header.persistentModelID)") ? "Double tap to collapse" : "Double tap to expand")
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

                    // Subcategories (only shown when expanded)
                    if expandedHeaders.contains("\(header.persistentModelID)") {
                        ForEach(header.sortedChildren) { subcategory in
                            let catKey = "\(subcategory.persistentModelID)"
                            let budgeted = localBudgets[catKey] ?? Decimal.zero
                            let avail = localAvailable[catKey] ?? subcategory.available(through: selectedMonth)
                            let categoryHasGoal = !goalsForCategory(subcategory).isEmpty
                            BudgetCategoryRow(
                                category: subcategory,
                                month: selectedMonth,
                                budgetedAmount: budgeted,
                                available: avail,
                                hasGoal: categoryHasGoal,
                                onBudgetChanged: { newAmount in
                                    saveBudget(for: subcategory, amount: newAmount)
                                },
                                onTapDetail: {
                                    detailCategory = subcategory
                                },
                                onFocusChanged: { focused in
                                    if focused {
                                        focusedCategory = subcategory
                                    } else {
                                        pendingHintAmount = nil
                                        // Delay clearing so that if another row gains focus
                                        // immediately, the hint bar stays visible without flicker
                                        Task { @MainActor in
                                            try? await Task.sleep(for: .milliseconds(100))
                                            if focusedCategory?.persistentModelID == subcategory.persistentModelID {
                                                focusedCategory = nil
                                            }
                                        }
                                    }
                                },
                                pendingHintAmount: $pendingHintAmount
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
        ContentUnavailableView(
            "No Categories Yet",
            systemImage: "tray",
            description: Text("Tap the gear icon to set up your budget categories.")
        )
    }

    // MARK: - Quick Fill Card

    /// Goals linked to the currently focused category
    private func goalsForCategory(_ category: Category) -> [SavingsGoal] {
        allGoals.filter { $0.linkedCategory?.persistentModelID == category.persistentModelID }
    }

    /// Floating card shown above the category list when editing a budget amount.
    /// Shows historical hints (last month, average) and goal target if a goal is linked.
    @ViewBuilder
    var keyboardHintBar: some View {
        if let cat = focusedCategory {
            let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth)
            let lastBudgeted = lastMonth.map { cat.budgeted(in: $0) } ?? .zero
            let lastSpent = lastMonth.map { -cat.activity(in: $0) } ?? .zero
            let avgBudgeted = cat.averageMonthlyBudgeted(before: selectedMonth, months: 12)
            let avgSpent = cat.averageMonthlySpending(before: selectedMonth, months: 12)
            let linkedGoals = goalsForCategory(cat)

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    // Card header
                    HStack {
                        Text(cat.emoji)
                        Text(cat.name)
                            .bold()
                            .lineLimit(1)
                        Spacer()
                        Text("Quick Fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }
                    .font(.subheadline)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    // Hint rows
                    VStack(spacing: 0) {
                        hintRow(label: "Last month", items: [
                            ("Budgeted", lastBudgeted),
                            ("Spent", lastSpent),
                        ])

                        Divider()
                            .padding(.leading)

                        hintRow(label: "12mo average", items: [
                            ("Budgeted", avgBudgeted),
                            ("Spent", avgSpent),
                        ])

                        // Goal hint rows
                        ForEach(linkedGoals) { goal in
                            if let monthlyTarget = goal.monthlyTarget(through: selectedMonth), monthlyTarget > 0 {
                                Divider()
                                    .padding(.leading)

                                goalHintRow(goal: goal, monthlyTarget: monthlyTarget)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .clipShape(.rect(cornerRadius: 8))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(.rect(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        }
    }

    /// A single hint row with a label on the left and tappable amount chips on the right
    private func hintRow(label: String, items: [(String, Decimal)]) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            ForEach(items.enumerated(), id: \.offset) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1, height: 24)
                        .padding(.horizontal, 12)
                }
                hintChip(label: item.0, amount: item.1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    /// A tappable hint chip showing label and amount
    private func hintChip(label: String, amount: Decimal) -> some View {
        Button {
            pendingHintAmount = amount
        } label: {
            VStack(spacing: 4) {
                Text(formatGBP(amount, currencyCode: currencyCode))
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label): \(formatGBP(amount, currencyCode: currencyCode))")
        .accessibilityHint("Double tap to fill budget with this amount")
    }

    /// Goal hint row showing the monthly target needed to stay on track
    private func goalHintRow(goal: SavingsGoal, monthlyTarget: Decimal) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "target")
                    .font(.caption)
                    .foregroundStyle(.purple)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let days = goal.daysRemaining, days > 0 {
                        Text("\(days)d left")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            hintChip(label: "Goal", amount: monthlyTarget)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
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

            // First budget allocation for this month — record as a meaningful event
            reviewPromptManager.recordEvent(.budgetMonthCompleted, requestReview: requestReview)
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
            if amount == .zero {
                // Remove pointless zero-value allocations to keep the database clean
                modelContext.delete(existing)
            } else {
                existing.budgeted = amount
            }
        } else if amount != .zero {
            let allocation = BudgetAllocation(budgeted: amount)
            allocation.category = category
            allocation.budgetMonth = bm
            modelContext.insert(allocation)
        }

        try? modelContext.save()
        HapticManager.light()

        // Log activity for shared budgets
        if sharingManager.isShared && delta != .zero {
            let message = "\(sharingManager.currentUserName) updated \(category.name) budget to \(amount)"
            sharingManager.logActivity(
                message: message,
                type: .editedBudget,
                context: modelContext
            )
        }
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
    let hasGoal: Bool
    let onBudgetChanged: (Decimal) -> Void
    var onTapDetail: (() -> Void)? = nil
    /// Signals the parent when this row gains/loses focus
    var onFocusChanged: ((Bool) -> Void)? = nil
    /// Parent sets this to apply a hint amount; row clears it after applying
    @Binding var pendingHintAmount: Decimal?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Raw digits string — user types "1536", we store "1536" and display £15.36
    @State private var rawDigits: String = ""
    @State private var previousDigits: String = ""  // backup for cancel-on-blur
    @State private var hasLoaded: Bool = false
    @State private var hasTyped: Bool = false  // tracks whether user typed anything while focused
    @State private var hintDigits: String = ""  // the rawDigits value set by the last hint (for replacement detection)
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

    /// Apply a hint amount — sets the display, marks as typed, and records hint for replacement detection
    private func applyHint(_ amount: Decimal) {
        let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
        let multiplier = Decimal(currency.minorUnitMultiplier)
        let absAmount = amount < 0 ? -amount : amount
        let minorUnits = NSDecimalNumber(decimal: absAmount * multiplier).intValue
        let digits = minorUnits > 0 ? String("\(minorUnits)".prefix(8)) : ""
        hintDigits = digits
        rawDigits = digits
        hasTyped = true
    }

    var body: some View {
        HStack(spacing: 4) {
            // Category name (left) — tap to open detail sheet
            Button {
                onTapDetail?()
            } label: {
                HStack(spacing: 4) {
                    Text(category.name)
                        .font(.subheadline)
                        .lineLimit(1)
                    if hasGoal {
                        Image(systemName: "target")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                            .accessibilityLabel("Has savings goal")
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(category.name) details\(hasGoal ? ", has savings goal" : "")")
            .accessibilityHint("Double tap to view category details")

            // Budgeted this month (middle, editable — pence-based ATM entry)
            ZStack {
                // Hidden text field bound to rawDigits
                TextField("", text: $rawDigits)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .opacity(0.01)
                    .frame(width: 80, height: 32)
                    .accessibilityHidden(true)
                    .onChange(of: isFocused) { _, focused in
                        if focused {
                            previousDigits = rawDigits
                            hasTyped = false
                            hintDigits = ""
                            rawDigits = ""
                        } else {
                            if !hasTyped {
                                rawDigits = previousDigits
                            } else {
                                onBudgetChanged(decimalAmount)
                            }
                        }
                        onFocusChanged?(focused)
                    }
                    .onChange(of: pendingHintAmount) { _, newHint in
                        // Only the focused row consumes the hint
                        if isFocused, let amount = newHint {
                            applyHint(amount)
                            pendingHintAmount = nil
                        }
                    }
                    .onChange(of: rawDigits) { _, newValue in
                        // After a hint sets rawDigits to e.g. "2500", the user's next keystroke
                        // appends to get "25003". Detect this: if newValue starts with the hint
                        // digits and has extra chars, keep only the extra (replacing the hint).
                        if !hintDigits.isEmpty && isFocused {
                            let digits = newValue.filter { $0.isNumber }
                            if digits == hintDigits {
                                // This is the hint itself landing — let it through
                            } else if digits.hasPrefix(hintDigits) && digits.count > hintDigits.count {
                                // User typed after hint — replace with just the new digit(s)
                                let fresh = String(digits.dropFirst(hintDigits.count))
                                hintDigits = ""
                                rawDigits = fresh
                                return
                            } else {
                                // Something else changed — clear hint tracking
                                hintDigits = ""
                            }
                        }

                        if isFocused {
                            let digits = newValue.filter { $0.isNumber }
                            if !digits.isEmpty {
                                hasTyped = true
                            }
                        }
                        let digits = newValue.filter { $0.isNumber }
                        let trimmed = String(digits.drop(while: { $0 == "0" }))
                        let capped = String(trimmed.prefix(8))
                        if rawDigits != capped {
                            rawDigits = capped
                        }
                    }

                // Visible display — tap to focus the hidden field
                Button {
                    isFocused = true
                } label: {
                    Text(displayString)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80, alignment: .trailing)
                        .contentTransition(reduceMotion ? .identity : .numericText())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Budgeted: \(displayString)")
                .accessibilityHint("Double tap to edit budget amount")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFocused ? Color.accentColor : Color(.separator).opacity(0.3), lineWidth: isFocused ? 2 : 1)
                    )
            )
            // Available balance (right, accent) — tap for detail
            Button {
                onTapDetail?()
            } label: {
                GBPText(amount: available, font: .subheadline.bold(), accentPositive: true)
                    .frame(width: 76, alignment: .trailing)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Available: \(formatGBP(available, currencyCode: currencyCode))\(available < 0 ? ", overspent" : "")")
            .accessibilityHint("Double tap to view category details")
        }
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(
            isFocused ? Color.accentColor.opacity(0.12) : Color(.systemBackground)
        )
        .sensoryFeedback(.selection, trigger: isFocused)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isFocused)
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            if budgetedAmount != .zero {
                let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
                let multiplier = Decimal(currency.minorUnitMultiplier)
                let absAmount = budgetedAmount < 0 ? -budgetedAmount : budgetedAmount
                let minorUnits = NSDecimalNumber(decimal: absAmount * multiplier).intValue
                rawDigits = minorUnits > 0 ? "\(minorUnits)" : ""
            }
        }
        .onChange(of: budgetedAmount) { _, newVal in
            if !isFocused {
                let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
                let multiplier = Decimal(currency.minorUnitMultiplier)
                let absVal = newVal < 0 ? -newVal : newVal
                let minorUnits = NSDecimalNumber(decimal: absVal * multiplier).intValue
                rawDigits = minorUnits > 0 ? "\(minorUnits)" : ""
            }
        }
    }

}

// MARK: - Category Detail Sheet

/// Half-sheet showing Budgeted / Activity / Available, historical context,
/// and all transactions for a category in a given month.
struct CategoryDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var allGoals: [SavingsGoal]
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    let category: Category
    let month: Date
    var onNavigateToGoal: ((PersistentIdentifier) -> Void)? = nil

    @State private var editingTransaction: Transaction? = nil

    var monthTransactions: [Transaction] {
        let calendar = Calendar.current
        return allTransactions.filter { transaction in
            guard let cat = transaction.category else { return false }
            guard cat.persistentModelID == category.persistentModelID else { return false }
            return calendar.isDate(transaction.date, equalTo: month, toGranularity: .month)
        }
    }

    /// Goals linked to this category
    private var linkedGoals: [SavingsGoal] {
        allGoals.filter { $0.linkedCategory?.persistentModelID == category.persistentModelID }
    }

    var budgeted: Decimal { category.budgeted(in: month) }
    var activity: Decimal { category.activity(in: month) }
    var available: Decimal { category.available(through: month) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary header
                VStack(spacing: 12) {
                    // Category name + emoji
                    HStack(spacing: 8) {
                        Text(category.emoji)
                            .font(.title2)
                        Text(category.name)
                            .font(.title3.bold())
                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    // Three-column summary: Budgeted | Activity | Available
                    HStack(spacing: 0) {
                        VStack(spacing: 4) {
                            GBPText(amount: budgeted, font: .headline)
                            Text("Budgeted")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)

                        VStack(spacing: 4) {
                            GBPText(amount: activity, font: .headline)
                            Text("Activity")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)

                        VStack(spacing: 4) {
                            GBPText(amount: available, font: .headline, accentPositive: true)
                            Text("Available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Available: \(formatGBP(available, currencyCode: currencyCode))\(available < 0 ? ", overspent" : "")")
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
                            CategoryGoalRow(goal: goal, month: month) {
                                dismiss()
                                onNavigateToGoal?(goal.persistentModelID)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                }

                Divider()

                // Transaction list for this category/month
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
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingTransaction) { transaction in
                EditTransactionView(transaction: transaction)
            }
        }
    }
}

/// A compact goal summary row shown inside the CategoryDetailSheet
struct CategoryGoalRow: View {
    let goal: SavingsGoal
    let month: Date
    var onViewGoal: (() -> Void)? = nil
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    private var goalProgress: Double {
        goal.progress(through: month)
    }

    private var progressColor: Color {
        if goal.isComplete(through: month) { return .green }
        if goalProgress >= 0.75 { return .blue }
        if goalProgress >= 0.5 { return .orange }
        return .accentColor
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                ProgressRingView(progress: goalProgress, color: progressColor, lineWidth: 3)
                    .frame(width: 28, height: 28)
                Text(goal.emoji)
                    .font(.caption)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.name)
                    .font(.subheadline.bold())
                HStack(spacing: 4) {
                    Text(formatGBP(goal.currentAmount(through: month), currencyCode: currencyCode))
                    Text("of")
                        .foregroundStyle(.tertiary)
                    Text(formatGBP(goal.targetAmount, currencyCode: currencyCode))
                }
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button("View Goal", systemImage: "chevron.right") {
                onViewGoal?()
            }
            .font(.caption)
            .labelStyle(.titleAndIcon)
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
        }
        .padding(12)
        .background(progressColor.opacity(0.06))
        .clipShape(.rect(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(goal.name) goal, \(Int(goalProgress * 100)) percent complete")
        .accessibilityHint("Double tap to view goal details")
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
            ActivityEntry.self,
        ], inMemory: true)
        .environment(SharingManager())
        .environment(ReviewPromptManager())
}
