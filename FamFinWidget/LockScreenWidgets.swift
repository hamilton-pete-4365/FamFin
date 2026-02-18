import SwiftUI
import WidgetKit

// MARK: - Circular Lock Screen Widget (accessoryCircular)

/// Shows a gauge representing budget utilization with the "To Budget" amount.
struct CircularToBudgetView: View {
    let entry: FamFinWidgetEntry

    private var toBudget: Decimal {
        entry.data.toBudgetAmount
    }

    /// Budget utilization as a value between 0 and 1.
    /// When all income is budgeted, this approaches 1.0.
    /// Clamped to 0...1 range.
    private var utilization: Double {
        let income = entry.data.totalIncome + entry.data.toBudgetAmount
        guard income > .zero else { return 0 }
        let budgeted = entry.data.totalBudgeted
        let ratio = NSDecimalNumber(decimal: budgeted / income).doubleValue
        return max(0, min(ratio, 1))
    }

    var body: some View {
        Gauge(value: utilization) {
            Text("TB")
        } currentValueLabel: {
            Text(WidgetCurrencyFormatter.formatCompact(toBudget, currencyCode: entry.data.currencyCode))
                .font(.caption2)
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircular)
        .widgetURL(URL(string: "famfin://budget"))
        .accessibilityLabel("To budget: \(WidgetCurrencyFormatter.format(toBudget, currencyCode: entry.data.currencyCode))")
    }
}

// MARK: - Rectangular Lock Screen Widget (accessoryRectangular)

/// Shows the primary account balance and the total balance across all accounts.
struct RectangularAccountView: View {
    let entry: FamFinWidgetEntry

    private var primaryAccount: WidgetDataProvider.AccountSnapshot? {
        entry.data.accounts.first
    }

    private var totalBalance: Decimal {
        entry.data.accounts.reduce(Decimal.zero) { $0 + $1.balance }
    }

    private var currencyCode: String {
        entry.data.currencyCode
    }

    var body: some View {
        VStack(alignment: .leading) {
            if let primary = primaryAccount {
                Text(primary.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(WidgetCurrencyFormatter.format(primary.balance, currencyCode: currencyCode))
                    .font(.headline)
                    .bold()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text("Total: \(WidgetCurrencyFormatter.format(totalBalance, currencyCode: currencyCode))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("FamFin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("No accounts")
                    .font(.headline)
            }
        }
        .widgetURL(URL(string: "famfin://accounts"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        if let primary = primaryAccount {
            return "\(primary.name): \(WidgetCurrencyFormatter.format(primary.balance, currencyCode: currencyCode)), Total: \(WidgetCurrencyFormatter.format(totalBalance, currencyCode: currencyCode))"
        }
        return "No accounts configured"
    }
}

// MARK: - Inline Lock Screen Widget (accessoryInline)

/// Shows "To Budget: $X,XXX" as a single line of text.
struct InlineToBudgetView: View {
    let entry: FamFinWidgetEntry

    var body: some View {
        Text("To Budget: \(WidgetCurrencyFormatter.formatCompact(entry.data.toBudgetAmount, currencyCode: entry.data.currencyCode))")
            .accessibilityLabel("To budget: \(WidgetCurrencyFormatter.format(entry.data.toBudgetAmount, currencyCode: entry.data.currencyCode))")
    }
}
