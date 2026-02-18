import SwiftUI
import WidgetKit

/// Small Home Screen widget showing the "To Budget" amount for the current month.
/// Green background tint when positive, amber/red when negative or zero.
struct SmallToBudgetView: View {
    let entry: FamFinWidgetEntry

    private var amount: Decimal {
        entry.data.toBudgetAmount
    }

    private var isHealthy: Bool {
        amount > .zero
    }

    private var backgroundColor: Color {
        if amount > .zero {
            return .green
        } else if amount == .zero {
            return .orange
        } else {
            return .red
        }
    }

    var body: some View {
        VStack {
            Spacer()

            Text(WidgetCurrencyFormatter.format(amount, currencyCode: entry.data.currencyCode))
                .font(.title2)
                .bold()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .accessibilityLabel("To budget amount: \(WidgetCurrencyFormatter.format(amount, currencyCode: entry.data.currencyCode))")

            Text("To Budget")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .containerBackground(backgroundColor.gradient, for: .widget)
        .widgetURL(URL(string: "famfin://budget"))
    }
}
