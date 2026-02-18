import SwiftUI
import SwiftData
import Charts

// MARK: - Data Model

struct MonthlyBalance: Identifiable {
    let id = UUID()
    let date: Date       // first of month
    let amount: Decimal
    let hasData: Bool     // false for months with no transactions yet
}

// MARK: - Reports View

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"
    @Query private var allTransactions: [Transaction]

    @State private var settings = ReportSettings()
    @State private var showingSettings = false

    /// Computed chart data keyed by chart config ID
    @State private var chartDataMap: [UUID: [MonthlyBalance]] = [:]
    /// Selected month index per chart
    @State private var selectionMap: [UUID: Int] = [:]
    @State private var hasData = false

    /// Lightweight fingerprint that changes when transactions are added, deleted, or edited
    private var transactionFingerprint: String {
        let count = allTransactions.count
        let total = allTransactions.reduce(Decimal.zero) { $0 + $1.amount }
        return "\(count)-\(total)"
    }

    /// Fingerprint that changes when report settings change
    private var settingsFingerprint: String {
        settings.data.charts
            .map { "\($0.id):\($0.name):\($0.accountFilter.rawValue):\($0.excludedAccountNames.sorted().joined(separator: ","))" }
            .joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            Group {
                if hasData {
                    ScrollView {
                        VStack(spacing: 16) {
                            AnalyticsNavigationSection()

                            ForEach(settings.charts) { chart in
                                BalanceChartCard(
                                    title: chart.name,
                                    data: chartDataMap[chart.id] ?? [],
                                    currencyCode: currencyCode,
                                    selectedIndex: Binding(
                                        get: { selectionMap[chart.id] },
                                        set: { selectionMap[chart.id] = $0 }
                                    )
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                    .background(Color(.systemGroupedBackground))
                } else {
                    ContentUnavailableView(
                        "No Reports Yet",
                        systemImage: "chart.bar.fill",
                        description: Text("Add some transactions to see reports here.")
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Reports")
                        .font(.headline)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Settings", systemImage: "gearshape") {
                        showingSettings = true
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                ReportSettingsView(settings: settings)
            }
            .onAppear { computeData() }
            .onChange(of: transactionFingerprint) { _, _ in
                computeData()
            }
            .onChange(of: settingsFingerprint) { _, _ in
                computeData()
            }
        }
    }

    // MARK: - Data Computation

    private func computeData() {
        let accounts: [Account]
        let allTransactions: [Transaction]

        do {
            accounts = try modelContext.fetch(FetchDescriptor<Account>())
            allTransactions = try modelContext.fetch(FetchDescriptor<Transaction>())
        } catch {
            return
        }

        guard !allTransactions.isEmpty else {
            hasData = false
            return
        }

        let calendar = Calendar.current

        // Start from the earliest transaction month through to current month
        let currentMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        let earliestDate = allTransactions.map(\.date).min() ?? Date()
        let earliestMonth = calendar.dateInterval(of: .month, for: earliestDate)?.start ?? earliestDate
        let startMonth = min(earliestMonth, currentMonth)

        // Generate all months from earliest data to now
        var months: [Date] = []
        var cursor = startMonth
        while cursor <= currentMonth {
            months.append(cursor)
            cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? cursor.addingTimeInterval(86400 * 31)
        }

        // Build lookup: account ID → [Transaction]
        var ownedByAccount: [PersistentIdentifier: [Transaction]] = [:]
        var incomingByAccount: [PersistentIdentifier: [Transaction]] = [:]

        for tx in allTransactions {
            if let accountID = tx.account?.persistentModelID {
                ownedByAccount[accountID, default: []].append(tx)
            }
            if let destID = tx.transferToAccount?.persistentModelID {
                incomingByAccount[destID, default: []].append(tx)
            }
        }

        // Compute balance for a set of accounts up to a given end-of-month date
        func totalBalance(for accountSet: [Account], before endOfMonth: Date) -> Decimal {
            var total: Decimal = .zero
            for account in accountSet {
                let accountID = account.persistentModelID
                let owned = ownedByAccount[accountID] ?? []
                let incoming = incomingByAccount[accountID] ?? []
                var balance: Decimal = .zero

                for tx in owned where tx.date < endOfMonth {
                    switch tx.type {
                    case .income: balance += tx.amount
                    case .expense: balance -= tx.amount
                    case .transfer: balance -= tx.amount
                    }
                }
                for tx in incoming where tx.date < endOfMonth {
                    balance += tx.amount
                }
                total += balance
            }
            return total
        }

        // Compute data for each chart config
        var newDataMap: [UUID: [MonthlyBalance]] = [:]
        var newSelectionMap: [UUID: Int] = [:]
        let lastIndex = months.count - 1

        for chart in settings.charts {
            let filtered: [Account]
            switch chart.accountFilter {
            case .all: filtered = accounts
            case .budgetOnly: filtered = accounts.filter(\.isBudget)
            case .trackingOnly: filtered = accounts.filter { !$0.isBudget }
            }
            let excluded = chart.excludedAccountNames
            let chartAccounts = filtered.filter { !excluded.contains($0.name) }

            var balances: [MonthlyBalance] = []
            for month in months {
                let endOfMonth = calendar.date(byAdding: .month, value: 1, to: month) ?? month
                let monthHasData = month >= earliestMonth
                let amount = monthHasData ? totalBalance(for: chartAccounts, before: endOfMonth) : .zero
                balances.append(MonthlyBalance(date: month, amount: amount, hasData: monthHasData))
            }

            newDataMap[chart.id] = balances
            // Keep existing selection if still valid, otherwise default to latest
            if let existing = selectionMap[chart.id], existing < months.count {
                newSelectionMap[chart.id] = existing
            } else {
                newSelectionMap[chart.id] = lastIndex
            }
        }

        self.chartDataMap = newDataMap
        self.selectionMap = newSelectionMap
        self.hasData = true
    }
}

// MARK: - Analytics Navigation Section

struct AnalyticsNavigationSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analytics")
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                AnalyticsNavCard(
                    title: "Spending Breakdown",
                    systemImage: "chart.pie.fill",
                    color: .blue
                ) {
                    SpendingBreakdownView()
                }

                AnalyticsNavCard(
                    title: "Spending Trends",
                    systemImage: "chart.xyaxis.line",
                    color: .green
                ) {
                    SpendingTrendsView()
                }

                AnalyticsNavCard(
                    title: "Income vs Expenses",
                    systemImage: "chart.bar.fill",
                    color: .orange
                ) {
                    IncomeVsExpenseView()
                }

                AnalyticsNavCard(
                    title: "Top Spenders",
                    systemImage: "list.number",
                    color: .purple
                ) {
                    TopSpendersView()
                }
            }
        }
    }
}

// MARK: - Analytics Navigation Card

struct AnalyticsNavCard<Destination: View>: View {
    let title: String
    let systemImage: String
    let color: Color
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .clipShape(.rect(cornerRadius: 12))
        }
        .accessibilityLabel(title)
        .accessibilityHint("Double tap to view \(title) analytics")
    }
}

// MARK: - Chart Card

struct BalanceChartCard: View {
    let title: String
    let data: [MonthlyBalance]
    let currencyCode: String
    @Binding var selectedIndex: Int?

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    private var displayIndex: Int {
        selectedIndex ?? (data.count - 1)
    }

    private var displayPoint: MonthlyBalance? {
        guard data.indices.contains(displayIndex) else { return nil }
        return data[displayIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: title on left, selected month + amount on right
            HStack(alignment: .top) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                if let point = displayPoint {
                    VStack(alignment: .trailing, spacing: 4) {
                        GBPText(amount: point.amount, font: .title3.bold())
                        Text(Self.monthFormatter.string(from: point.date))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(title): \(formatGBP(point.amount, currencyCode: currencyCode)) in \(Self.monthFormatter.string(from: point.date))\(point.amount < 0 ? ", negative" : "")")
                }
            }

            // Bar chart — tappable bars, scrollable horizontally
            BalanceBarChart(
                data: data,
                currencyCode: currencyCode,
                selectedIndex: $selectedIndex
            )
            .frame(height: 180)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(title) chart with \(data.count) months")
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Bar Chart (scrollable, tappable)

struct BalanceBarChart: View {
    let data: [MonthlyBalance]
    let currencyCode: String
    @Binding var selectedIndex: Int?

    private var currency: SupportedCurrency {
        SupportedCurrency(rawValue: currencyCode) ?? .gbp
    }

    /// Width per bar — tuned for ~5–6 visible at a time in a standard card
    private let barSlotWidth: CGFloat = 54

    /// Total chart width based on data count
    private var chartWidth: CGFloat {
        CGFloat(data.count) * barSlotWidth
    }

    /// Month label formatter
    private static let monthLabel: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    var body: some View {
        GeometryReader { geometry in
            let visibleWidth = geometry.size.width
            let chartHeight = geometry.size.height

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
                            barColumn(index: index, point: point, chartHeight: chartHeight)
                                .id(index)
                        }
                    }
                    .padding(.horizontal, 4)
                    .frame(minWidth: visibleWidth)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    // Scroll to the rightmost (most recent) bar
                    if !data.isEmpty {
                        proxy.scrollTo(data.count - 1, anchor: .trailing)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func barColumn(index: Int, point: MonthlyBalance, chartHeight: CGFloat) -> some View {
        let isSelected = index == selectedIndex
        // Reserve space for month label at bottom
        let labelHeight: CGFloat = 20
        let barAreaHeight = chartHeight - labelHeight - 4

        let maxAmount = data.filter(\.hasData).map { NSDecimalNumber(decimal: $0.amount).doubleValue }.max() ?? 1
        let minAmount = data.filter(\.hasData).map { NSDecimalNumber(decimal: $0.amount).doubleValue }.min() ?? 0
        // Handle case where all values are the same or zero
        let range = max(maxAmount - min(minAmount, 0), 1)
        let baseline = min(minAmount, 0)
        let doubleAmount = point.hasData ? NSDecimalNumber(decimal: point.amount).doubleValue : 0
        let normalized = (doubleAmount - baseline) / range
        let barHeight = max(point.hasData ? CGFloat(normalized) * barAreaHeight : 2, 2)
        let isNegative = point.hasData && point.amount < 0

        VStack(spacing: 4) {
            Spacer(minLength: 0)

            // Bar
            Button {
                selectedIndex = index
            } label: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(barFill(isSelected: isSelected, hasData: point.hasData, isNegative: isNegative))
                    .frame(width: barSlotWidth - 10, height: barHeight)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(Self.monthLabel.string(from: point.date)): \(point.hasData ? formatGBP(point.amount, currencyCode: currencyCode) : "No data")\(isNegative ? ", negative" : "")")
            .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select this month")
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            // Month label
            Text(Self.monthLabel.string(from: point.date))
                .font(.caption2)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(height: labelHeight)
                .accessibilityHidden(true)
        }
        .frame(width: barSlotWidth)
    }

    private func barFill(isSelected: Bool, hasData: Bool, isNegative: Bool = false) -> Color {
        if !hasData {
            return Color(.separator).opacity(0.15)
        }
        let baseColor: Color = isNegative ? .red : .accentColor
        if isSelected {
            return baseColor
        }
        return baseColor.opacity(0.4)
    }
}

#Preview {
    ReportsView()
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
