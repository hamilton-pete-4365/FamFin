import Foundation

/// Currency formatting for widget views.
/// Mirrors the main app's CurrencyFormatter but works without @AppStorage.
enum WidgetCurrencyFormatter {

    /// Format a Decimal as a currency string using the provided currency code.
    static func format(_ amount: Decimal, currencyCode: String) -> String {
        let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.currencySymbol = currency.symbol
        formatter.minimumFractionDigits = currency.minorUnitDigits
        formatter.maximumFractionDigits = currency.minorUnitDigits

        let absVal = amount < 0 ? -amount : amount
        let fallback = currency.hasMinorUnits ? "\(currency.symbol)0.00" : "\(currency.symbol)0"
        let formatted = formatter.string(from: absVal as NSDecimalNumber) ?? fallback

        if amount < 0 {
            return "-\(formatted)"
        }
        return formatted
    }

    /// Format with a sign prefix (+ for positive, - for negative).
    static func formatSigned(_ amount: Decimal, currencyCode: String) -> String {
        let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.currencySymbol = currency.symbol
        formatter.minimumFractionDigits = currency.minorUnitDigits
        formatter.maximumFractionDigits = currency.minorUnitDigits

        let absVal = amount < 0 ? -amount : amount
        let fallback = currency.hasMinorUnits ? "\(currency.symbol)0.00" : "\(currency.symbol)0"
        let formatted = formatter.string(from: absVal as NSDecimalNumber) ?? fallback

        if amount < 0 {
            return "-\(formatted)"
        } else if amount > 0 {
            return "+\(formatted)"
        }
        return formatted
    }

    /// Format a compact currency string for Lock Screen widgets (shorter).
    static func formatCompact(_ amount: Decimal, currencyCode: String) -> String {
        let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
        let absVal = amount < 0 ? -amount : amount

        // For large amounts, use compact notation
        let doubleVal = NSDecimalNumber(decimal: absVal).doubleValue
        let sign = amount < 0 ? "-" : ""

        if doubleVal >= 10000 {
            let thousands = doubleVal / 1000
            return "\(sign)\(currency.symbol)\(Int(thousands))k"
        } else if doubleVal >= 1000 {
            let thousands = doubleVal / 1000
            let formatted = String(format: "%.1f", thousands)
                .replacing(".0", with: "")
            return "\(sign)\(currency.symbol)\(formatted)k"
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.currencySymbol = currency.symbol
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = currency.hasMinorUnits ? 2 : 0

        let formatted = formatter.string(from: absVal as NSDecimalNumber) ?? "\(currency.symbol)\(absVal)"
        return amount < 0 ? "-\(formatted)" : formatted
    }
}
