import SwiftUI
import SwiftData
import Charts

// MARK: - Data Model

struct CategorySpending: Identifiable {
    let id = UUID()
    let categoryName: String
    let emoji: String
    let amount: Decimal
    let percentage: Double
}

// MARK: - Spending Breakdown View

struct SpendingBreakdownView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    @State private var selectedMonth: Date = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var spendingData: [CategorySpending] = []
    @State private var selectedCategory: String?

    private var totalSpending: Decimal {
        spendingData.reduce(.zero) { $0 + $1.amount }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MonthPickerCard(selectedMonth: $selectedMonth)

                if spendingData.isEmpty {
                    ContentUnavailableView(
                        "No Spending",
                        systemImage: "chart.pie",
                        description: Text("No expenses recorded for this month.")
                    )
                    .padding(.top)
                } else {
                    DonutChartCard(
                        spendingData: spendingData,
                        totalSpending: totalSpending,
                        currencyCode: currencyCode,
                        selectedCategory: $selectedCategory
                    )

                    SpendingLegend(
                        spendingData: spendingData,
                        currencyCode: currencyCode,
                        selectedCategory: $selectedCategory
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Spending Breakdown")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { computeData() }
        .onChange(of: selectedMonth) { _, _ in computeData() }
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

        // Filter to expenses in the selected month on budget accounts
        let monthExpenses = transactions.filter { tx in
            tx.type == .expense &&
            tx.date >= startOfMonth &&
            tx.date < endOfMonth &&
            tx.account?.isBudget == true
        }

        // Group by category
        var byCategoryName: [String: (emoji: String, total: Decimal)] = [:]
        for tx in monthExpenses {
            let name = tx.category?.name ?? "Uncategorized"
            let emoji = tx.category?.emoji ?? "📦"
            byCategoryName[name, default: (emoji: emoji, total: .zero)].total += tx.amount
        }

        let grandTotal = byCategoryName.values.reduce(Decimal.zero) { $0 + $1.total }
        guard grandTotal > 0 else {
            spendingData = []
            return
        }

        let sorted = byCategoryName.sorted { $0.value.total > $1.value.total }
        spendingData = sorted.map { entry in
            let pct = NSDecimalNumber(decimal: entry.value.total).doubleValue / NSDecimalNumber(decimal: grandTotal).doubleValue * 100
            return CategorySpending(
                categoryName: entry.key,
                emoji: entry.value.emoji,
                amount: entry.value.total,
                percentage: pct
            )
        }
    }
}

// MARK: - Month Picker Card

struct MonthPickerCard: View {
    @Binding var selectedMonth: Date

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var body: some View {
        HStack {
            Button("Previous Month", systemImage: "chevron.left") {
                moveMonth(by: -1)
            }
            .labelStyle(.iconOnly)

            Spacer()

            Text(Self.monthFormatter.string(from: selectedMonth))
                .font(.headline)

            Spacer()

            Button("Next Month", systemImage: "chevron.right") {
                moveMonth(by: 1)
            }
            .labelStyle(.iconOnly)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Month selector: \(Self.monthFormatter.string(from: selectedMonth))")
    }

    private func moveMonth(by offset: Int) {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: selectedMonth) {
            selectedMonth = newMonth
        }
    }
}

// MARK: - Donut Chart Card

struct DonutChartCard: View {
    let spendingData: [CategorySpending]
    let totalSpending: Decimal
    let currencyCode: String
    @Binding var selectedCategory: String?

    private static let chartColors: [Color] = [
        .blue, .green, .orange, .purple, .pink,
        .teal, .indigo, .mint, .cyan, .brown,
        .red, .yellow
    ]

    var body: some View {
        VStack(spacing: 12) {
            Chart(spendingData) { item in
                SectorMark(
                    angle: .value("Amount", NSDecimalNumber(decimal: item.amount).doubleValue),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(colorFor(item.categoryName))
                .opacity(selectedCategory == nil || selectedCategory == item.categoryName ? 1.0 : 0.3)
                .accessibilityLabel("\(item.emoji) \(item.categoryName)")
                .accessibilityValue("\(formatGBP(item.amount, currencyCode: currencyCode)), \(item.percentage, format: .number.precision(.fractionLength(1))) percent")
            }
            .chartAngleSelection(value: $selectedCategory)
            .frame(height: 240)
            .chartBackground { _ in
                VStack(spacing: 4) {
                    if let selected = selectedCategory,
                       let data = spendingData.first(where: { $0.categoryName == selected }) {
                        Text(data.emoji)
                            .font(.title)
                        Text(data.categoryName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        GBPText(amount: data.amount, font: .headline)
                    } else {
                        Text("Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        GBPText(amount: totalSpending, font: .headline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private func colorFor(_ categoryName: String) -> Color {
        guard let index = spendingData.firstIndex(where: { $0.categoryName == categoryName }) else {
            return .gray
        }
        return Self.chartColors[index % Self.chartColors.count]
    }
}

// MARK: - Spending Legend

struct SpendingLegend: View {
    let spendingData: [CategorySpending]
    let currencyCode: String
    @Binding var selectedCategory: String?

    private static let chartColors: [Color] = [
        .blue, .green, .orange, .purple, .pink,
        .teal, .indigo, .mint, .cyan, .brown,
        .red, .yellow
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(spendingData.enumerated(), id: \.element.id) { index, item in
                SpendingLegendRow(
                    item: item,
                    color: Self.chartColors[index % Self.chartColors.count],
                    currencyCode: currencyCode,
                    isSelected: selectedCategory == item.categoryName,
                    onTap: {
                        if selectedCategory == item.categoryName {
                            selectedCategory = nil
                        } else {
                            selectedCategory = item.categoryName
                        }
                    }
                )

                if index < spendingData.count - 1 {
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
}

// MARK: - Spending Legend Row

struct SpendingLegendRow: View {
    let item: CategorySpending
    let color: Color
    let currencyCode: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                    .accessibilityHidden(true)

                Text("\(item.emoji) \(item.categoryName)")
                    .foregroundStyle(.primary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatGBP(item.amount, currencyCode: currencyCode))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text(item.percentage, format: .number.precision(.fractionLength(1)))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    + Text("%")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(isSelected ? color.opacity(0.1) : .clear)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.emoji) \(item.categoryName)")
        .accessibilityValue("\(formatGBP(item.amount, currencyCode: currencyCode)), \(item.percentage, format: .number.precision(.fractionLength(1))) percent")
        .accessibilityHint(isSelected ? "Currently selected. Double tap to deselect." : "Double tap to highlight in chart.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack {
        SpendingBreakdownView()
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
