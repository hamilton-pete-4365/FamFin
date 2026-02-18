import SwiftUI
import WidgetKit

/// Medium Home Screen widget showing top account balances and a total.
struct MediumAccountsView: View {
    let entry: FamFinWidgetEntry

    private var displayAccounts: [WidgetDataProvider.AccountSnapshot] {
        Array(entry.data.accounts.prefix(4))
    }

    private var totalBalance: Decimal {
        entry.data.accounts.reduce(Decimal.zero) { $0 + $1.balance }
    }

    private var currencyCode: String {
        entry.data.currencyCode
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Accounts")
                .font(.caption)
                .foregroundStyle(.secondary)

            if displayAccounts.isEmpty {
                Spacer()
                Text("No accounts yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(displayAccounts, id: \.name) { account in
                    AccountRow(account: account, currencyCode: currencyCode)
                }

                Spacer(minLength: 0)

                Divider()

                HStack {
                    Text("Total")
                        .font(.subheadline)
                        .bold()
                    Spacer()
                    Text(WidgetCurrencyFormatter.format(totalBalance, currencyCode: currencyCode))
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(totalBalance < .zero ? .red : .primary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Total balance: \(WidgetCurrencyFormatter.format(totalBalance, currencyCode: currencyCode))")
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "famfin://accounts"))
    }
}

// MARK: - Account Row

private struct AccountRow: View {
    let account: WidgetDataProvider.AccountSnapshot
    let currencyCode: String

    var body: some View {
        HStack {
            Text(account.name)
                .font(.caption)
                .lineLimit(1)
            Spacer()
            Text(WidgetCurrencyFormatter.format(account.balance, currencyCode: currencyCode))
                .font(.caption)
                .foregroundStyle(account.balance < .zero ? .red : .primary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(account.name): \(WidgetCurrencyFormatter.format(account.balance, currencyCode: currencyCode))")
    }
}
