import Foundation

/// Supported currencies with their symbols and codes
enum SupportedCurrency: String, CaseIterable, Identifiable {
    case gbp = "GBP"
    case usd = "USD"
    case eur = "EUR"
    case cad = "CAD"
    case aud = "AUD"
    case nzd = "NZD"
    case chf = "CHF"
    case sek = "SEK"
    case nok = "NOK"
    case dkk = "DKK"
    case jpy = "JPY"
    case inr = "INR"
    case zar = "ZAR"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gbp: return "British Pound"
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .cad: return "Canadian Dollar"
        case .aud: return "Australian Dollar"
        case .nzd: return "New Zealand Dollar"
        case .chf: return "Swiss Franc"
        case .sek: return "Swedish Krona"
        case .nok: return "Norwegian Krone"
        case .dkk: return "Danish Krone"
        case .jpy: return "Japanese Yen"
        case .inr: return "Indian Rupee"
        case .zar: return "South African Rand"
        }
    }

    var symbol: String {
        switch self {
        case .gbp: return "£"
        case .usd: return "$"
        case .eur: return "€"
        case .cad: return "$"
        case .aud: return "$"
        case .nzd: return "$"
        case .chf: return "Fr"
        case .sek: return "kr"
        case .nok: return "kr"
        case .dkk: return "kr"
        case .jpy: return "¥"
        case .inr: return "₹"
        case .zar: return "R"
        }
    }

    /// Whether this currency uses minor units (pence/cents). JPY does not.
    var hasMinorUnits: Bool {
        self != .jpy
    }

    var minorUnitDigits: Int {
        hasMinorUnits ? 2 : 0
    }

    /// Multiplier to convert between minor units and major units (100 for pence/cents, 1 for JPY)
    var minorUnitMultiplier: Int {
        hasMinorUnits ? 100 : 1
    }
}

/// Global access to the user's chosen currency.
/// Reads from UserDefaults via @AppStorage-compatible key.
struct CurrencySettings {
    static let key = "selectedCurrencyCode"

    static var current: SupportedCurrency {
        let code = UserDefaults.standard.string(forKey: key) ?? "GBP"
        return SupportedCurrency(rawValue: code) ?? .gbp
    }

    /// Sync the currency code to the shared App Group UserDefaults
    /// so that the widget extension can read it.
    /// No-ops gracefully when App Group entitlements are unavailable.
    static func syncToSharedDefaults() {
        guard SharedModelContainer.storeURL != nil else { return }
        let code = UserDefaults.standard.string(forKey: key) ?? "GBP"
        UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)?
            .set(code, forKey: key)
    }
}
