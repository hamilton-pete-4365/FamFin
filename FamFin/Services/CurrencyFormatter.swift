import SwiftUI

/// Returns a NumberFormatter configured for the given currency
private func currencyFormatter(for currency: SupportedCurrency) -> NumberFormatter {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = currency.rawValue
    f.minimumFractionDigits = currency.minorUnitDigits
    f.maximumFractionDigits = currency.minorUnitDigits
    return f
}

/// Format an absolute Decimal as a currency string
private func formatAbsCurrency(_ amount: Decimal, currency: SupportedCurrency) -> String {
    let absVal = amount < 0 ? -amount : amount
    let formatter = currencyFormatter(for: currency)
    let fallback = currency.hasMinorUnits ? "\(currency.symbol)0.00" : "\(currency.symbol)0"
    return formatter.string(from: absVal as NSDecimalNumber) ?? fallback
}

/// Formats currency values consistently across the app.
/// Negative values shown in red with brackets: (£9.00)
/// Positive values optionally show + prefix.
/// Uses @AppStorage to reactively update when currency changes.
struct GBPText: View {
    let amount: Decimal
    var font: Font = .headline
    var showSign: Bool = false
    /// When true, positive/zero amounts use the app accent colour instead of .primary
    var accentPositive: Bool = false

    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    private var currency: SupportedCurrency {
        SupportedCurrency(rawValue: currencyCode) ?? .gbp
    }

    private var positiveStyle: Color {
        accentPositive ? .accentColor : .primary
    }

    var body: some View {
        Text(formatted)
            .font(font)
            .foregroundStyle(amount < 0 ? .red : positiveStyle)
    }

    private var formatted: String {
        let value = formatAbsCurrency(amount, currency: currency)
        if amount < 0 {
            return "(\(value))"
        } else if showSign && amount > 0 {
            return "+\(value)"
        }
        return value
    }
}

/// For transaction rows: shows the amount with appropriate formatting
/// Income: +£150.00 in green
/// Expense: (£150.00) in red
/// Transfer: £150.00 in secondary
struct TransactionAmountText: View {
    let amount: Decimal
    let type: TransactionType

    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    private var currency: SupportedCurrency {
        SupportedCurrency(rawValue: currencyCode) ?? .gbp
    }

    var body: some View {
        Text(formatted)
            .font(.headline)
            .foregroundStyle(color)
    }

    private var formatted: String {
        let value = formatAbsCurrency(amount, currency: currency)
        switch type {
        case .income:
            return "+\(value)"
        case .expense:
            return "(\(value))"
        case .transfer:
            return value
        }
    }

    private var color: Color {
        switch type {
        case .income: return .green
        case .expense: return .red
        case .transfer: return .secondary
        }
    }
}

/// Format a Decimal as a currency string for non-View contexts.
/// Pass the currency code from @AppStorage to ensure reactivity.
func formatGBP(_ amount: Decimal, currencyCode: String = "GBP") -> String {
    let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
    let value = formatAbsCurrency(amount, currency: currency)
    if amount < 0 {
        return "(\(value))"
    }
    return value
}

/// Format pence/cents as a display string with the given currency symbol.
/// Pass the currency code from @AppStorage to ensure reactivity.
func formatPence(_ pence: Int, currencyCode: String = "GBP") -> String {
    let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
    if currency.hasMinorUnits {
        let major = pence / 100
        let minor = pence % 100
        return String(format: "%@%d.%02d", currency.symbol, major, minor)
    } else {
        return "\(currency.symbol)\(pence)"
    }
}
