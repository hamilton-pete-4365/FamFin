import SwiftUI
import SwiftData
import Charts

// MARK: - Data Models

struct SpenderEntry: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let amount: Decimal
    let percentage: Double
}

enum SpenderGrouping: String, CaseIterable, Identifiable {
    case byCategory = "By Category"
    case byPayee = "By Payee"

    var id: String { rawValue }
}

// MARK: - Top Spenders View

struct TopSpendersView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    @State private var selectedMonth: Date = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var grouping: SpenderGrouping = .byCategory
    @State private var spenders: [SpenderEntry] = []

    private var totalSpending: Decimal {
        spenders.reduce(.zero) { $0 + $1.amount }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MonthPickerCard(selectedMonth: $selectedMonth)

                SpenderGroupingPicker(grouping: $grouping)

                if spenders.isEmpty {
                    ContentUnavailableView(
                        "No Spending",
                        systemImage: "list.number",
                        description: Text("No expenses recorded for this month.")
                    )
                    .padding(.top)
                } else {
                    TopSpendersChartCard(
                        spenders: Array(spenders.prefix(10)),
                        currencyCode: currencyCode
                    )

                    TopSpendersListCard(
                        spenders: spenders,
                        totalSpending: totalSpending,
                        currencyCode: currencyCode
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Top Spenders")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { computeData() }
        .onChange(of: selectedMonth) { _, _ in computeData() }
        .onChange(of: grouping) { _, _ in computeData() }
    }

    private func computeData() {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: selectedMonth)
        guard let startOfMonth = calendar.date(from: comps),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else { return }

        let transactions: [Transaction]
        do {
            transactions = try modelContext.fetch(FetchDescriptor<Transaction>())
        } catch {
            return
        }

        // Filter expenses in the selected month on budget accounts
        let monthExpenses = transactions.filter { tx in
            tx.type == .expense &&
            tx.date >= startOfMonth &&
            tx.date < endOfMonth &&
            tx.account?.isBudget == true
        }

        var totals: [String: (emoji: String, total: Decimal)] = [:]

        switch grouping {
        case .byCategory:
            for tx in monthExpenses {
                let name = tx.category?.name ?? "Uncategorized"
                let emoji = tx.category?.emoji ?? "📦"
                totals[name, default: (emoji: emoji, total: .zero)].total += tx.amount
            }
        case .byPayee:
            for tx in monthExpenses {
                let name = tx.payee.isEmpty ? "Unknown" : tx.payee
                totals[name, default: (emoji: "🏪", total: .zero)].total += tx.amount
            }
        }

        let grandTotal = totals.values.reduce(Decimal.zero) { $0 + $1.total }
        guard grandTotal > 0 else {
            spenders = []
            return
        }

        let sorted = totals.sorted { $0.value.total > $1.value.total }
        spenders = sorted.map { entry in
            let pct = NSDecimalNumber(decimal: entry.value.total).doubleValue / NSDecimalNumber(decimal: grandTotal).doubleValue * 100
            return SpenderEntry(
                name: entry.key,
                emoji: entry.value.emoji,
                amount: entry.value.total,
                percentage: pct
            )
        }
    }
}

// MARK: - Grouping Picker

struct SpenderGroupingPicker: View {
    @Binding var grouping: SpenderGrouping

    var body: some View {
        Picker("Group By", selection: $grouping) {
            ForEach(SpenderGrouping.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Horizontal Bar Chart Card

struct TopSpendersChartCard: View {
    let spenders: [SpenderEntry]
    let currencyCode: String

    private static let barColors: [Color] = [
        .blue, .green, .orange, .purple, .pink,
        .teal, .indigo, .mint, .cyan, .brown
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Spending")
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            Chart(spenders) { spender in
                BarMark(
                    x: .value("Amount", NSDecimalNumber(decimal: spender.amount).doubleValue),
                    y: .value("Name", spender.name)
                )
                .foregroundStyle(colorFor(spender.name))
                .annotation(position: .trailing, alignment: .leading) {
                    Text(formatGBP(spender.amount, currencyCode: currencyCode))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(spender.name)
                .accessibilityValue(formatGBP(spender.amount, currencyCode: currencyCode))
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(spenders.count) * 36 + 20)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Horizontal bar chart of top \(spenders.count) spenders")
    }

    private func colorFor(_ name: String) -> Color {
        guard let index = spenders.firstIndex(where: { $0.name == name }) else { return .gray }
        return Self.barColors[index % Self.barColors.count]
    }
}

// MARK: - Ranked List Card

struct TopSpendersListCard: View {
    let spenders: [SpenderEntry]
    let totalSpending: Decimal
    let currencyCode: String

    var body: some View {
        VStack(spacing: 0) {
            ForEach(spenders.enumerated(), id: \.element.id) { index, spender in
                TopSpenderRow(
                    rank: index + 1,
                    spender: spender,
                    totalSpending: totalSpending,
                    currencyCode: currencyCode
                )

                if index < spenders.count - 1 {
                    Divider()
                        .padding(.leading, 48)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Top Spender Row

struct TopSpenderRow: View {
    let rank: Int
    let spender: SpenderEntry
    let totalSpending: Decimal
    let currencyCode: String

    private var barWidthFraction: CGFloat {
        guard totalSpending > 0 else { return 0 }
        return CGFloat(NSDecimalNumber(decimal: spender.amount / totalSpending).doubleValue)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(rank)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Text("\(spender.emoji) \(spender.name)")

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatGBP(spender.amount, currencyCode: currencyCode))
                        .bold()
                        .monospacedDigit()
                    Text(spender.percentage, format: .number.precision(.fractionLength(1)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    + Text("%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: geometry.size.width * barWidthFraction, height: 4)
            }
            .frame(height: 4)
            .padding(.leading, 24)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(rank): \(spender.emoji) \(spender.name), \(formatGBP(spender.amount, currencyCode: currencyCode)), \(spender.percentage, format: .number.precision(.fractionLength(1))) percent")
    }
}

#Preview {
    NavigationStack {
        TopSpendersView()
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
