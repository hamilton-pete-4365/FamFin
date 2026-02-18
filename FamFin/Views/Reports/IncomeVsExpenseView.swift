import SwiftUI
import SwiftData
import Charts

// MARK: - Data Models

struct MonthlyIncomeExpense: Identifiable {
    let id = UUID()
    let date: Date
    let income: Double
    let expenses: Double

    var net: Double { income - expenses }
}

struct IncomeExpenseBarEntry: Identifiable {
    let id = UUID()
    let date: Date
    let type: String
    let amount: Double
}

enum IncomeExpensePeriod: String, CaseIterable, Identifiable {
    case sixMonths = "6M"
    case twelveMonths = "12M"

    var id: String { rawValue }

    var monthCount: Int {
        switch self {
        case .sixMonths: return 6
        case .twelveMonths: return 12
        }
    }
}

// MARK: - Income vs Expense View

struct IncomeVsExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    @State private var selectedPeriod: IncomeExpensePeriod = .sixMonths
    @State private var monthlyData: [MonthlyIncomeExpense] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                IncomeExpensePeriodPicker(selectedPeriod: $selectedPeriod)

                if monthlyData.isEmpty {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.bar",
                        description: Text("Record some income and expenses to see this report.")
                    )
                    .padding(.top)
                } else {
                    IncomeExpenseChartCard(
                        monthlyData: monthlyData,
                        currencyCode: currencyCode
                    )

                    IncomeExpenseSummaryCard(
                        monthlyData: monthlyData,
                        currencyCode: currencyCode
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Income vs Expenses")
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

        // Build list of months
        var months: [Date] = []
        for offset in stride(from: -(selectedPeriod.monthCount - 1), through: 0, by: 1) {
            if let month = calendar.date(byAdding: .month, value: offset, to: currentMonthStart) {
                months.append(month)
            }
        }

        // Compute income and expenses per month (on budget accounts only)
        var data: [MonthlyIncomeExpense] = []
        for month in months {
            guard let endOfMonth = calendar.date(byAdding: .month, value: 1, to: month) else { continue }

            let monthTransactions = transactions.filter { tx in
                tx.date >= month &&
                tx.date < endOfMonth &&
                tx.account?.isBudget == true
            }

            var income: Decimal = .zero
            var expenses: Decimal = .zero

            for tx in monthTransactions {
                switch tx.type {
                case .income:
                    income += tx.amount
                case .expense:
                    expenses += tx.amount
                case .transfer:
                    // Cross-boundary transfers: budget -> tracking counts as expense-like
                    if tx.transferNeedsCategory {
                        if tx.account?.isBudget == true {
                            expenses += tx.amount
                        } else {
                            income += tx.amount
                        }
                    }
                }
            }

            data.append(MonthlyIncomeExpense(
                date: month,
                income: NSDecimalNumber(decimal: income).doubleValue,
                expenses: NSDecimalNumber(decimal: expenses).doubleValue
            ))
        }

        monthlyData = data
    }
}

// MARK: - Period Picker

struct IncomeExpensePeriodPicker: View {
    @Binding var selectedPeriod: IncomeExpensePeriod

    var body: some View {
        Picker("Time Period", selection: $selectedPeriod) {
            ForEach(IncomeExpensePeriod.allCases) { period in
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

// MARK: - Chart Card

struct IncomeExpenseChartCard: View {
    let monthlyData: [MonthlyIncomeExpense]
    let currencyCode: String

    private var barEntries: [IncomeExpenseBarEntry] {
        monthlyData.flatMap { month in
            [
                IncomeExpenseBarEntry(date: month.date, type: "Income", amount: month.income),
                IncomeExpenseBarEntry(date: month.date, type: "Expenses", amount: month.expenses),
            ]
        }
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Overview")
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            Chart {
                // Stacked bar marks for income and expenses
                ForEach(barEntries) { entry in
                    BarMark(
                        x: .value("Month", entry.date, unit: .month),
                        y: .value("Amount", entry.amount)
                    )
                    .foregroundStyle(by: .value("Type", entry.type))
                    .position(by: .value("Type", entry.type))
                    .accessibilityLabel("\(entry.type)")
                    .accessibilityValue("\(Self.monthFormatter.string(from: entry.date)): \(formatGBP(Decimal(entry.amount), currencyCode: currencyCode))")
                }

                // Net line overlay
                ForEach(monthlyData) { month in
                    LineMark(
                        x: .value("Month", month.date, unit: .month),
                        y: .value("Net", month.net)
                    )
                    .foregroundStyle(.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .symbol(.circle)
                    .symbolSize(30)
                    .accessibilityLabel("Net")
                    .accessibilityValue("\(Self.monthFormatter.string(from: month.date)): \(formatGBP(Decimal(month.net), currencyCode: currencyCode))")
                }
            }
            .chartForegroundStyleScale([
                "Income": Color.green,
                "Expenses": Color.red,
            ])
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 260)

            // Legend
            HStack(spacing: 16) {
                ChartLegendItem(color: .green, label: "Income")
                ChartLegendItem(color: .red, label: "Expenses")
                NetLegendItem()
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Income vs expenses chart showing \(monthlyData.count) months")
    }
}

// MARK: - Chart Legend Item

struct ChartLegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Net Legend Item

struct NetLegendItem: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "line.diagonal")
                .font(.caption2)
                .foregroundStyle(.primary)
            Text("Net")
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Summary Card

struct IncomeExpenseSummaryCard: View {
    let monthlyData: [MonthlyIncomeExpense]
    let currencyCode: String

    private var totalIncome: Decimal {
        Decimal(monthlyData.reduce(0) { $0 + $1.income })
    }

    private var totalExpenses: Decimal {
        Decimal(monthlyData.reduce(0) { $0 + $1.expenses })
    }

    private var totalNet: Decimal {
        totalIncome - totalExpenses
    }

    private var avgMonthlyIncome: Decimal {
        guard !monthlyData.isEmpty else { return .zero }
        return totalIncome / Decimal(monthlyData.count)
    }

    private var avgMonthlyExpenses: Decimal {
        guard !monthlyData.isEmpty else { return .zero }
        return totalExpenses / Decimal(monthlyData.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            SummaryRow(label: "Total Income", amount: totalIncome, currencyCode: currencyCode, color: .green)
            Divider().padding(.leading)
            SummaryRow(label: "Total Expenses", amount: totalExpenses, currencyCode: currencyCode, color: .red)
            Divider().padding(.leading)
            SummaryRow(label: "Net", amount: totalNet, currencyCode: currencyCode, color: totalNet >= 0 ? .green : .red)
            Divider().padding(.leading)
            SummaryRow(label: "Avg Monthly Income", amount: avgMonthlyIncome, currencyCode: currencyCode, color: .secondary)
            Divider().padding(.leading)
            SummaryRow(label: "Avg Monthly Expenses", amount: avgMonthlyExpenses, currencyCode: currencyCode, color: .secondary)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Summary Row

struct SummaryRow: View {
    let label: String
    let amount: Decimal
    let currencyCode: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatGBP(amount, currencyCode: currencyCode))
                .bold()
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(formatGBP(amount, currencyCode: currencyCode))")
    }
}

#Preview {
    NavigationStack {
        IncomeVsExpenseView()
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
