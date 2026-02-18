import SwiftUI
import SwiftData
import Charts

// MARK: - Data Models

struct MonthlySpendingPoint: Identifiable {
    let id = UUID()
    let date: Date
    let categoryName: String
    let amount: Double
}

enum TrendPeriod: String, CaseIterable, Identifiable {
    case threeMonths = "3M"
    case sixMonths = "6M"
    case twelveMonths = "12M"

    var id: String { rawValue }

    var monthCount: Int {
        switch self {
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .twelveMonths: return 12
        }
    }
}

// MARK: - Spending Trends View

struct SpendingTrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    @State private var selectedPeriod: TrendPeriod = .sixMonths
    @State private var trendData: [MonthlySpendingPoint] = []
    @State private var topCategories: [String] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PeriodPicker(selectedPeriod: $selectedPeriod)

                if trendData.isEmpty {
                    ContentUnavailableView(
                        "No Spending Trends",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Record some expenses to see spending trends over time.")
                    )
                    .padding(.top)
                } else {
                    TrendChartCard(
                        trendData: trendData,
                        topCategories: topCategories,
                        currencyCode: currencyCode
                    )

                    TrendCategoryLegend(
                        topCategories: topCategories,
                        trendData: trendData,
                        currencyCode: currencyCode
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Spending Trends")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { computeData() }
        .onChange(of: selectedPeriod) { _, _ in computeData() }
    }

    private func computeData() {
        let calendar = Calendar.current
        let currentMonthStart = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()

        let transactions: [Transaction]
        do {
            transactions = try modelContext.fetch(FetchDescriptor<Transaction>())
        } catch {
            return
        }

        // Build list of months in the period
        var months: [Date] = []
        for offset in stride(from: -(selectedPeriod.monthCount - 1), through: 0, by: 1) {
            if let month = calendar.date(byAdding: .month, value: offset, to: currentMonthStart) {
                months.append(month)
            }
        }

        guard let earliestMonth = months.first else { return }

        // Filter expenses within the period on budget accounts
        let periodExpenses = transactions.filter { tx in
            tx.type == .expense &&
            tx.date >= earliestMonth &&
            tx.account?.isBudget == true
        }

        // Accumulate spending per category per month
        var categoryMonthTotals: [String: [Date: Decimal]] = [:]
        for tx in periodExpenses {
            let name = tx.category?.name ?? "Uncategorized"
            let monthStart = calendar.dateInterval(of: .month, for: tx.date)?.start ?? tx.date
            categoryMonthTotals[name, default: [:]][monthStart, default: .zero] += tx.amount
        }

        // Determine top 5 categories by total spending
        let categoryTotals = categoryMonthTotals.map { (name: $0.key, total: $0.value.values.reduce(.zero, +)) }
        let sortedCategories = categoryTotals.sorted { $0.total > $1.total }
        let top5 = Array(sortedCategories.prefix(5).map(\.name))

        // Build chart data points
        var points: [MonthlySpendingPoint] = []
        for categoryName in top5 {
            let monthTotals = categoryMonthTotals[categoryName] ?? [:]
            for month in months {
                let amount = monthTotals[month] ?? .zero
                points.append(MonthlySpendingPoint(
                    date: month,
                    categoryName: categoryName,
                    amount: NSDecimalNumber(decimal: amount).doubleValue
                ))
            }
        }

        topCategories = top5
        trendData = points
    }
}

// MARK: - Period Picker

struct PeriodPicker: View {
    @Binding var selectedPeriod: TrendPeriod

    var body: some View {
        Picker("Time Period", selection: $selectedPeriod) {
            ForEach(TrendPeriod.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Trend Chart Card

struct TrendChartCard: View {
    let trendData: [MonthlySpendingPoint]
    let topCategories: [String]
    let currencyCode: String

    private static let trendColors: [Color] = [
        .blue, .green, .orange, .purple, .pink
    ]

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Categories")
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            Chart(trendData) { point in
                LineMark(
                    x: .value("Month", point.date, unit: .month),
                    y: .value("Amount", point.amount)
                )
                .foregroundStyle(by: .value("Category", point.categoryName))
                .symbol(by: .value("Category", point.categoryName))
                .interpolationMethod(.catmullRom)
                .accessibilityLabel("\(point.categoryName)")
                .accessibilityValue("\(Self.monthFormatter.string(from: point.date)): \(formatGBP(Decimal(point.amount), currencyCode: currencyCode))")
            }
            .chartForegroundStyleScale(domain: topCategories, range: Self.trendColors)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartLegend(.hidden)
            .frame(height: 240)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Spending trends chart showing top \(topCategories.count) categories")
    }
}

// MARK: - Trend Category Legend

struct TrendCategoryLegend: View {
    let topCategories: [String]
    let trendData: [MonthlySpendingPoint]
    let currencyCode: String

    private static let trendColors: [Color] = [
        .blue, .green, .orange, .purple, .pink
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(topCategories.enumerated(), id: \.element) { index, categoryName in
                TrendLegendRow(
                    categoryName: categoryName,
                    color: Self.trendColors[index % Self.trendColors.count],
                    totalAmount: totalForCategory(categoryName),
                    currencyCode: currencyCode
                )

                if index < topCategories.count - 1 {
                    Divider()
                        .padding(.leading, 32)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private func totalForCategory(_ name: String) -> Decimal {
        let points = trendData.filter { $0.categoryName == name }
        return Decimal(points.reduce(0) { $0 + $1.amount })
    }
}

// MARK: - Trend Legend Row

struct TrendLegendRow: View {
    let categoryName: String
    let color: Color
    let totalAmount: Decimal
    let currencyCode: String

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)

            Text(categoryName)

            Spacer()

            Text(formatGBP(totalAmount, currencyCode: currencyCode))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(categoryName): \(formatGBP(totalAmount, currencyCode: currencyCode)) total")
    }
}

#Preview {
    NavigationStack {
        SpendingTrendsView()
    }
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
