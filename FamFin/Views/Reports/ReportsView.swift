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

    @State private var netWorthData: [MonthlyBalance] = []
    @State private var budgetData: [MonthlyBalance] = []
    @State private var trackingData: [MonthlyBalance] = []
    @State private var hasData = false

    // Each chart tracks its own selected month index
    @State private var netWorthSelection: Int?
    @State private var budgetSelection: Int?
    @State private var trackingSelection: Int?

    var body: some View {
        NavigationStack {
            Group {
                if hasData {
                    ScrollView {
                        VStack(spacing: 16) {
                            BalanceChartCard(
                                title: "Net Worth",
                                data: netWorthData,
                                currencyCode: currencyCode,
                                selectedIndex: $netWorthSelection
                            )

                            BalanceChartCard(
                                title: "Budget Accounts",
                                data: budgetData,
                                currencyCode: currencyCode,
                                selectedIndex: $budgetSelection
                            )

                            BalanceChartCard(
                                title: "Tracking Accounts",
                                data: trackingData,
                                currencyCode: currencyCode,
                                selectedIndex: $trackingSelection
                            )
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
            }
            .onAppear { computeData() }
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

        var netWorth: [MonthlyBalance] = []
        var budget: [MonthlyBalance] = []
        var tracking: [MonthlyBalance] = []

        for month in months {
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: month) ?? month
            let monthHasData = month >= earliestMonth
            var budgetTotal: Decimal = .zero
            var trackingTotal: Decimal = .zero

            if monthHasData {
                for account in accounts {
                    let accountID = account.persistentModelID
                    let owned = ownedByAccount[accountID] ?? []
                    let incoming = incomingByAccount[accountID] ?? []

                    var balance: Decimal = .zero

                    for tx in owned where tx.date < endOfMonth {
                        switch tx.type {
                        case .income:
                            balance += tx.amount
                        case .expense:
                            balance -= tx.amount
                        case .transfer:
                            balance -= tx.amount
                        }
                    }

                    for tx in incoming where tx.date < endOfMonth {
                        balance += tx.amount
                    }

                    if account.isBudget {
                        budgetTotal += balance
                    } else {
                        trackingTotal += balance
                    }
                }
            }

            let total = budgetTotal + trackingTotal
            netWorth.append(MonthlyBalance(date: month, amount: total, hasData: monthHasData))
            budget.append(MonthlyBalance(date: month, amount: budgetTotal, hasData: monthHasData))
            tracking.append(MonthlyBalance(date: month, amount: trackingTotal, hasData: monthHasData))
        }

        self.netWorthData = netWorth
        self.budgetData = budget
        self.trackingData = tracking
        self.hasData = true

        // Default selection: latest month (last index)
        let lastIndex = months.count - 1
        self.netWorthSelection = lastIndex
        self.budgetSelection = lastIndex
        self.trackingSelection = lastIndex
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
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                if let point = displayPoint {
                    VStack(alignment: .trailing, spacing: 2) {
                        GBPText(amount: point.amount, font: .title3.bold())
                        Text(Self.monthFormatter.string(from: point.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Bar chart — tappable bars, scrollable horizontally
            BalanceBarChart(
                data: data,
                currencyCode: currencyCode,
                selectedIndex: $selectedIndex
            )
            .frame(height: 180)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 12))
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

    /// Width per bar — tuned for ~6 visible at a time in a standard card
    private let barSlotWidth: CGFloat = 48

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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
                            barColumn(index: index, point: point, chartHeight: chartHeight)
                                .id(index)
                        }
                    }
                    .padding(.horizontal, 4)
                    .frame(minWidth: visibleWidth)
                }
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
        let labelHeight: CGFloat = 18
        let barAreaHeight = chartHeight - labelHeight - 4

        let maxAmount = data.filter(\.hasData).map { NSDecimalNumber(decimal: $0.amount).doubleValue }.max() ?? 1
        let minAmount = data.filter(\.hasData).map { NSDecimalNumber(decimal: $0.amount).doubleValue }.min() ?? 0
        // Handle case where all values are the same or zero
        let range = max(maxAmount - min(minAmount, 0), 1)
        let baseline = min(minAmount, 0)
        let doubleAmount = point.hasData ? NSDecimalNumber(decimal: point.amount).doubleValue : 0
        let normalized = (doubleAmount - baseline) / range
        let barHeight = max(point.hasData ? CGFloat(normalized) * barAreaHeight : 2, 2)

        VStack(spacing: 2) {
            Spacer(minLength: 0)

            // Bar
            Button {
                selectedIndex = index
            } label: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(barFill(isSelected: isSelected, hasData: point.hasData))
                    .frame(width: barSlotWidth - 10, height: barHeight)
            }
            .buttonStyle(.plain)

            // Month label
            Text(Self.monthLabel.string(from: point.date))
                .font(.system(size: 9))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(height: labelHeight)
        }
        .frame(width: barSlotWidth)
    }

    private func barFill(isSelected: Bool, hasData: Bool) -> Color {
        if !hasData {
            return Color(.separator).opacity(0.15)
        }
        if isSelected {
            return Color.accentColor
        }
        return Color.accentColor.opacity(0.4)
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
