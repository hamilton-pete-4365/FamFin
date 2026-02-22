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
    @State private var isEditingCategories = false
    @State private var overspentExpanded = false
    @State private var showMonthPicker = false
    @State private var navigationPath = NavigationPath()
    /// The category currently being edited via the custom keypad.
    @State private var focusedCategory: Category? = nil
    /// Tracks whether the keypad was already showing, to control scroll delay.
    @State private var keypadWasAlreadyVisible = false
    /// Set to true when the focused row is not fully visible and needs scrolling.
    @State private var focusedRowNeedsScroll = false
    /// The visible height of the budget list, used for scroll visibility checks.
    @State private var budgetListHeight: CGFloat = 0
    @State private var showQuickFill = false
    @State private var showAddTransaction = false
    @State private var showAutoFill = false
    /// The shared keypad engine — single source of truth for amount entry state.
    @State private var engine = AmountKeypadEngine()
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    // MARK: - Computed

    /// The system "To Budget" category
    var toBudgetCategory: Category? {
        allCategories.first { $0.isSystem && $0.name == DefaultCategories.toBudgetName }
    }

    var headerCategories: [Category] {
        allCategories
            .filter { $0.isHeader && !$0.isSystem && !$0.isHidden }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Subcategories whose available balance is negative this month
    var overspentCategories: [(id: String, name: String, amount: Decimal)] {
        headerCategories.flatMap { $0.visibleSortedChildren }
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

                if headerCategories.isEmpty {
                    emptyState
                } else {
                    categoryList
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if engine.isActive {
                    VStack(spacing: 0) {
                        AmountActionBar(
                            showQuickFill: $showQuickFill,
                            onDetails: { navigateToDetail() }
                        ) {
                            if let cat = focusedCategory {
                                QuickFillPopover(
                                    category: cat,
                                    month: selectedMonth,
                                    currencyCode: currencyCode,
                                    onSelectAmount: { amount in
                                        engine.applyHint(amount)
                                        showQuickFill = false
                                    }
                                )
                            }
                        }

                        AmountKeypad(
                            engine: engine,
                            onCancel: { handleCancel() },
                            onDone: { amount in handleDone(amount) }
                        )
                    }
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: engine.isActive)
            .gesture(
                DragGesture(minimumDistance: 50, coordinateSpace: .local)
                    .onEnded { value in
                        // Only respond to primarily horizontal swipes
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
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: focusedCategory?.persistentModelID)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileButton()
                }
                ToolbarItem(placement: .principal) {
                    Text("Budget")
                        .font(.headline)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Transaction", systemImage: "plus") {
                        showAddTransaction = true
                    }
                }
                ToolbarSpacer(.fixed, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Auto-Fill Budget", systemImage: "sparkles") {
                            showAutoFill = true
                        }
                        Button("Manage Categories", systemImage: "slider.horizontal.3") {
                            isEditingCategories = true
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $isEditingCategories) {
                NavigationStack {
                    ManageCategoriesView()
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView()
            }
            .sheet(isPresented: $showAutoFill) {
                AutoFillBudgetView(month: selectedMonth) {
                    syncLocalBudgets()
                }
            }
            .navigationDestination(for: Category.self) { category in
                CategoryDetailView(category: category, month: selectedMonth)
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

    /// Whether the selected month is the current calendar month.
    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    /// Navigate back to the current calendar month.
    private func goToToday() {
        // Auto-save and dismiss keypad
        if engine.isActive, let cat = focusedCategory {
            saveBudget(for: cat, amount: engine.doneTapped())
            focusedCategory = nil
        }

        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: Date())
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            selectedMonth = calendar.date(from: comps) ?? Date()
        }
    }

    var monthSelector: some View {
        HStack {
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
                MonthYearPicker(selectedMonth: $selectedMonth)
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
                // Position in the left or right gap without affecting layout.
                // Horizontal padding clears the chevron buttons so the pill
                // sits between the chevron and the month label.
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

    // MARK: - Category List

    var categoryList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(headerCategories) { header in
                    Section {
                        // Collapsible header row with inline column labels
                        Button {
                            withAnimation(reduceMotion ? nil : .default) {
                                let headerKey = "\(header.persistentModelID)"
                                if expandedHeaders.contains(headerKey) {
                                    // Collapsing — dismiss keypad if the focused category belongs to this header
                                    if let focused = focusedCategory,
                                       header.visibleSortedChildren.contains(where: { $0.persistentModelID == focused.persistentModelID }) {
                                        let amount = engine.doneTapped()
                                        saveBudget(for: focused, amount: amount)
                                        focusedCategory = nil
                                    }
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
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                Spacer()

                                // Budgeted column with label
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Budgeted")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Text(formatGBP(headerBudgeted(header), currencyCode: currencyCode))
                                        .font(.subheadline)
                                        .bold()
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                }
                                .frame(width: 100, alignment: .trailing)

                                // Available column with label
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Available")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    let avail = headerAvailable(header)
                                    Text(formatGBP(avail, currencyCode: currencyCode))
                                        .font(.subheadline)
                                        .bold()
                                        .monospacedDigit()
                                        .foregroundStyle(avail < 0 ? .red : Color.accentColor)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                }
                                .frame(width: 88, alignment: .trailing)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityLabel("\(header.name), budgeted \(formatGBP(headerBudgeted(header), currencyCode: currencyCode)), available \(formatGBP(headerAvailable(header), currencyCode: currencyCode))\(headerAvailable(header) < 0 ? ", overspent" : "")")
                        .accessibilityHint(expandedHeaders.contains("\(header.persistentModelID)") ? "Double tap to collapse" : "Double tap to expand")
                        .listRowBackground(Color(.secondarySystemBackground))
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

                        // Subcategories (only shown when expanded)
                        if expandedHeaders.contains("\(header.persistentModelID)") {
                            ForEach(header.visibleSortedChildren) { subcategory in
                                let catKey = "\(subcategory.persistentModelID)"
                                let budgeted = localBudgets[catKey] ?? Decimal.zero
                                let avail = localAvailable[catKey] ?? subcategory.available(through: selectedMonth)
                                let isCategoryFocused = focusedCategory?.persistentModelID == subcategory.persistentModelID

                                BudgetCategoryRow(
                                    category: subcategory,
                                    budgetedDisplay: isCategoryFocused
                                        ? engine.displayString
                                        : formatGBP(budgeted, currencyCode: currencyCode),
                                    available: avail,
                                    isFocused: isCategoryFocused,
                                    expressionDisplay: isCategoryFocused
                                        ? engine.expressionDisplayString
                                        : nil,
                                    onTap: { activateKeypad(for: subcategory) }
                                )
                                .id(subcategory.persistentModelID)
                                .onGeometryChange(for: CGRect.self) { proxy in
                                    proxy.frame(in: .named("budgetList"))
                                } action: { frame in
                                    if isCategoryFocused {
                                        let fullyVisible = frame.minY >= 0
                                            && frame.maxY <= budgetListHeight
                                        focusedRowNeedsScroll = !fullyVisible
                                    }
                                }
                                .listRowBackground(
                                    isCategoryFocused
                                        ? Color.accentColor.opacity(0.12)
                                        : Color(.systemBackground)
                                )
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .coordinateSpace(.named("budgetList"))
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                budgetListHeight = height
            }
            // When a math expression appears (user presses + or −) the row
            // grows taller. Wait for the layout to settle, then scroll if
            // the row now extends beyond the visible area.
            .onChange(of: engine.expressionDisplayString) { oldValue, newValue in
                // Only react when an expression appears (nil → non-nil).
                guard oldValue == nil, newValue != nil,
                      let id = focusedCategory?.persistentModelID else { return }
                Task { @MainActor in
                    // Let the VStack resize and onGeometryChange update the flag.
                    try? await Task.sleep(for: .milliseconds(100))
                    guard focusedRowNeedsScroll else { return }
                    withAnimation {
                        proxy.scrollTo(id, anchor: nil)
                    }
                }
            }
            .onChange(of: focusedCategory?.persistentModelID) { _, newID in
                guard let id = newID else {
                    // Keypad dismissed — reset stale state so the
                    // next fresh open doesn't carry over old values.
                    focusedRowNeedsScroll = false
                    return
                }
                // Wait for the keypad to appear and the safeAreaInset to resize
                // the List's visible area before scrolling.
                let delay: Duration = keypadWasAlreadyVisible
                    ? .milliseconds(50) // Row-to-row: keypad already sized, just settle
                    : .milliseconds(400) // Fresh open: wait for spring animation to finish
                let wasAlreadyVisible = keypadWasAlreadyVisible
                Task { @MainActor in
                    try? await Task.sleep(for: delay)
                    // Row-to-row: only scroll if the row isn't fully visible,
                    // to avoid unnecessary jumps between nearby rows.
                    if wasAlreadyVisible && !focusedRowNeedsScroll { return }
                    withAnimation {
                        // anchor: nil scrolls the minimum amount needed —
                        // no movement if the row is already fully visible,
                        // just enough to reveal it if partially obscured.
                        proxy.scrollTo(id, anchor: nil)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    var emptyState: some View {
        ContentUnavailableView {
            Label("No Categories Yet", systemImage: "tray")
        } description: {
            Text("Set up your budget categories to start tracking spending.")
        } actions: {
            Button("Set Up Categories") {
                isEditingCategories = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Keypad Interaction

    /// Activate the keypad for a category. If already active for a different row, auto-save first.
    func activateKeypad(for category: Category) {
        // If already focused on this category, no-op
        if focusedCategory?.persistentModelID == category.persistentModelID {
            return
        }

        keypadWasAlreadyVisible = engine.isActive

        // If editing a different row, auto-save it first
        if engine.isActive, let previousCategory = focusedCategory {
            let amount = engine.doneTapped()
            saveBudget(for: previousCategory, amount: amount)
        }

        // Activate for the new category
        let catKey = "\(category.persistentModelID)"
        let budgeted = localBudgets[catKey] ?? Decimal.zero
        let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
        let multiplier = Decimal(currency.minorUnitMultiplier)
        let absBudgeted = budgeted < 0 ? -budgeted : budgeted
        let pence = NSDecimalNumber(decimal: absBudgeted * multiplier).intValue

        engine.activate(currentPence: pence, currencyCode: currencyCode)
        focusedCategory = category
    }

    /// Handle the Done key — save and dismiss the keypad.
    func handleDone(_ amount: Decimal) {
        guard let category = focusedCategory else { return }
        saveBudget(for: category, amount: amount)
        focusedCategory = nil
    }

    /// Handle the Cancel key — revert to original value and dismiss the keypad.
    func handleCancel() {
        _ = engine.cancelTapped()
        focusedCategory = nil
    }

    /// Handle the Details button — auto-save and navigate to category detail.
    func navigateToDetail() {
        guard let category = focusedCategory else { return }
        let amount = engine.doneTapped()
        saveBudget(for: category, amount: amount)
        focusedCategory = nil
        navigationPath.append(category)
    }

    // MARK: - Helpers

    func changeMonth(by offset: Int) {
        // Auto-save and dismiss keypad when changing months
        if engine.isActive, let cat = focusedCategory {
            saveBudget(for: cat, amount: engine.doneTapped())
            focusedCategory = nil
        }

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
        header.visibleSortedChildren.reduce(Decimal.zero) { $0 + budgetedAmount(for: $1) }
    }

    func headerAvailable(_ header: Category) -> Decimal {
        header.visibleSortedChildren.reduce(Decimal.zero) { sum, child in
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

// MARK: - Budget Category Row (display-only, keypad-driven)

/// Displays a single budget category row with name, budgeted amount, and available balance.
///
/// All editing is handled by the parent's `AmountKeypadEngine` — this row is purely display.
/// Tapping the row triggers `onTap` to activate the keypad for this category.
struct BudgetCategoryRow: View {
    let category: Category
    /// Live display string — driven by the engine when focused, else formatted budgetedAmount.
    let budgetedDisplay: String
    let available: Decimal
    let isFocused: Bool
    /// Second-line math expression (e.g. "£1.50 + £0.50"), nil when none.
    let expressionDisplay: String?
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 8) {
                Text(category.name)
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer()

                // Budgeted amount (updates live from engine when focused).
                // When a math expression is active, both lines are shown in a
                // VStack so they centre vertically within the row.
                VStack(alignment: .trailing, spacing: 2) {
                    Text(budgetedDisplay)
                        .font(.subheadline.bold())
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(reduceMotion ? .identity : .numericText())

                    if let expr = expressionDisplay {
                        Text(expr)
                            .font(.subheadline.bold())
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .transition(.opacity)
                    }
                }
                .frame(width: 100, alignment: .trailing)

                // Available balance
                GBPText(amount: available, font: .subheadline.bold(), accentPositive: true)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: 88, alignment: .trailing)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint("Double tap to edit budget amount")
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .sensoryFeedback(.selection, trigger: isFocused)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isFocused)
    }

    private var accessibilityLabelText: String {
        var parts = [category.name]
        if isFocused {
            parts.append("editing")
            if let expr = expressionDisplay {
                parts.append(expr)
            } else {
                parts.append("current amount \(budgetedDisplay)")
            }
        } else {
            parts.append("budgeted \(budgetedDisplay)")
        }
        parts.append("available \(formatGBP(available, currencyCode: currencyCode))")
        if available < 0 { parts.append("overspent") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Category Detail Sheet

/// Half-sheet showing Budgeted / Activity / Available, historical context,
/// and all transactions for a category in a given month.
struct CategoryDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    let category: Category
    let month: Date

    @State private var editingTransaction: Transaction? = nil

    var monthTransactions: [Transaction] {
        let calendar = Calendar.current
        return allTransactions.filter { transaction in
            guard let cat = transaction.category else { return false }
            guard cat.persistentModelID == category.persistentModelID else { return false }
            return calendar.isDate(transaction.date, equalTo: month, toGranularity: .month)
        }
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

// MARK: - Preview

#Preview {
    BudgetView()
        .modelContainer(for: [
            Account.self,
            Transaction.self,
            Category.self,
            BudgetMonth.self,
            BudgetAllocation.self,
            Payee.self,
            ActivityEntry.self,
        ], inMemory: true)
        .environment(SharingManager())
        .environment(ReviewPromptManager())
}
