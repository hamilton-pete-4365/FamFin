import SwiftUI
import WidgetKit

/// Large Home Screen widget showing "To Budget" amount and overspent/top categories.
struct LargeBudgetOverviewView: View {
    let entry: FamFinWidgetEntry

    private var toBudget: Decimal {
        entry.data.toBudgetAmount
    }

    private var currencyCode: String {
        entry.data.currencyCode
    }

    private var hasOverspent: Bool {
        !entry.data.overspentCategories.isEmpty
    }

    /// Show overspent categories if any exist, otherwise show top remaining categories.
    private var displayCategories: [WidgetDataProvider.CategorySnapshot] {
        if hasOverspent {
            return Array(entry.data.overspentCategories.prefix(5))
        } else {
            return Array(entry.data.topCategories.prefix(5))
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            // "To Budget" header
            ToBudgetHeader(amount: toBudget, currencyCode: currencyCode)

            Divider()

            // Section header
            Text(hasOverspent ? "Overspent" : "Top Categories")
                .font(.caption)
                .foregroundStyle(.secondary)

            if displayCategories.isEmpty {
                Spacer()
                Text("No budget data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(displayCategories, id: \.name) { category in
                    CategoryRow(
                        category: category,
                        currencyCode: currencyCode,
                        isOverspent: hasOverspent
                    )
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "famfin://budget"))
    }
}

// MARK: - To Budget Header

private struct ToBudgetHeader: View {
    let amount: Decimal
    let currencyCode: String

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("To Budget")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(WidgetCurrencyFormatter.format(amount, currencyCode: currencyCode))
                    .font(.title3)
                    .bold()
                    .foregroundStyle(amount < .zero ? .red : (amount == .zero ? .orange : .green))
            }
            Spacer()

            Image(systemName: amount > .zero ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(amount > .zero ? .green : (amount == .zero ? .orange : .red))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("To budget: \(WidgetCurrencyFormatter.format(amount, currencyCode: currencyCode))")
    }
}

// MARK: - Category Row

private struct CategoryRow: View {
    let category: WidgetDataProvider.CategorySnapshot
    let currencyCode: String
    let isOverspent: Bool

    var body: some View {
        HStack {
            Text(category.emoji)
                .font(.caption)
            Text(category.name)
                .font(.caption)
                .lineLimit(1)
            Spacer()
            Text(WidgetCurrencyFormatter.format(category.available, currencyCode: currencyCode))
                .font(.caption)
                .bold()
                .foregroundStyle(isOverspent ? .red : .green)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.name): \(WidgetCurrencyFormatter.format(category.available, currencyCode: currencyCode))")
    }
}
