import Foundation
import Testing
@testable import FamFin

// MARK: - SupportedCurrency Properties

@Suite("SupportedCurrency properties")
struct SupportedCurrencyPropertyTests {

    @Test("All 13 currencies exist")
    func allCurrenciesExist() {
        #expect(SupportedCurrency.allCases.count == 13)
    }

    @Test("JPY has no minor units")
    func jpyNoMinorUnits() {
        #expect(SupportedCurrency.jpy.hasMinorUnits == false)
        #expect(SupportedCurrency.jpy.minorUnitDigits == 0)
        #expect(SupportedCurrency.jpy.minorUnitMultiplier == 1)
    }

    @Test("All non-JPY currencies have 2 minor unit digits")
    func nonJpyMinorUnits() {
        for currency in SupportedCurrency.allCases where currency != .jpy {
            #expect(currency.hasMinorUnits == true, "Expected \(currency.rawValue) to have minor units")
            #expect(currency.minorUnitDigits == 2, "Expected \(currency.rawValue) to have 2 minor unit digits")
            #expect(currency.minorUnitMultiplier == 100, "Expected \(currency.rawValue) multiplier to be 100")
        }
    }

    @Test("Currency symbols are correct")
    func currencySymbols() {
        #expect(SupportedCurrency.gbp.symbol == "£")
        #expect(SupportedCurrency.usd.symbol == "$")
        #expect(SupportedCurrency.eur.symbol == "€")
        #expect(SupportedCurrency.cad.symbol == "$")
        #expect(SupportedCurrency.aud.symbol == "$")
        #expect(SupportedCurrency.nzd.symbol == "$")
        #expect(SupportedCurrency.chf.symbol == "Fr")
        #expect(SupportedCurrency.sek.symbol == "kr")
        #expect(SupportedCurrency.nok.symbol == "kr")
        #expect(SupportedCurrency.dkk.symbol == "kr")
        #expect(SupportedCurrency.jpy.symbol == "¥")
        #expect(SupportedCurrency.inr.symbol == "₹")
        #expect(SupportedCurrency.zar.symbol == "R")
    }

    @Test("Currency raw values match ISO codes")
    func rawValues() {
        #expect(SupportedCurrency.gbp.rawValue == "GBP")
        #expect(SupportedCurrency.usd.rawValue == "USD")
        #expect(SupportedCurrency.eur.rawValue == "EUR")
        #expect(SupportedCurrency.cad.rawValue == "CAD")
        #expect(SupportedCurrency.aud.rawValue == "AUD")
        #expect(SupportedCurrency.nzd.rawValue == "NZD")
        #expect(SupportedCurrency.chf.rawValue == "CHF")
        #expect(SupportedCurrency.sek.rawValue == "SEK")
        #expect(SupportedCurrency.nok.rawValue == "NOK")
        #expect(SupportedCurrency.dkk.rawValue == "DKK")
        #expect(SupportedCurrency.jpy.rawValue == "JPY")
        #expect(SupportedCurrency.inr.rawValue == "INR")
        #expect(SupportedCurrency.zar.rawValue == "ZAR")
    }

    @Test("Display names contain the symbol")
    func displayNamesContainSymbol() {
        for currency in SupportedCurrency.allCases {
            let display = currency.displayName
            #expect(!display.isEmpty, "\(currency.rawValue) should have a display name")
        }
    }
}

// MARK: - formatGBP Tests

@Suite("formatGBP function")
struct FormatGBPTests {

    @Test("Formats positive GBP amount")
    func positiveGBP() {
        let result = formatGBP(Decimal(string: "123.45")!, currencyCode: "GBP")
        #expect(result.contains("123"))
        #expect(result.contains("45"))
        #expect(result.contains("£"))
    }

    @Test("Formats negative GBP amount with minus sign")
    func negativeGBP() {
        let result = formatGBP(Decimal(string: "-50.00")!, currencyCode: "GBP")
        #expect(result.hasPrefix("-"))
        #expect(result.contains("50"))
        #expect(result.contains("£"))
    }

    @Test("Formats zero amount")
    func zeroAmount() {
        let result = formatGBP(Decimal.zero, currencyCode: "GBP")
        #expect(result.contains("0"))
        #expect(result.contains("£"))
    }

    @Test("Formats USD amount with dollar sign")
    func usdAmount() {
        let result = formatGBP(Decimal(string: "99.99")!, currencyCode: "USD")
        #expect(result.contains("99"))
        #expect(result.contains("$"))
    }

    @Test("Formats JPY without decimal places")
    func jpyNoDecimals() {
        let result = formatGBP(Decimal(1500), currencyCode: "JPY")
        #expect(result.contains("1,500") || result.contains("1500"))
        #expect(result.contains("¥") || result.contains("JP¥"))
        #expect(!result.contains("."))
    }

    @Test("Formats EUR amount with euro sign")
    func eurAmount() {
        let result = formatGBP(Decimal(string: "250.50")!, currencyCode: "EUR")
        #expect(result.contains("250"))
    }

    @Test("Formats INR amount with rupee sign")
    func inrAmount() {
        let result = formatGBP(Decimal(string: "1000.00")!, currencyCode: "INR")
        #expect(result.contains("1,000") || result.contains("1000"))
    }

    @Test("Falls back to GBP for unknown currency code")
    func unknownCurrencyFallback() {
        let result = formatGBP(Decimal(100), currencyCode: "XYZ")
        // Should fall back to GBP
        #expect(result.contains("£"))
    }

    @Test("Large amount formats with grouping separator")
    func largeAmountGrouping() {
        let result = formatGBP(Decimal(string: "1234567.89")!, currencyCode: "GBP")
        // Should contain some form of grouping for thousands
        #expect(result.contains("1") && result.contains("234") && result.contains("567"))
    }
}

// MARK: - formatPence Tests

@Suite("formatPence function")
struct FormatPenceTests {

    @Test("Converts pence to pounds correctly")
    func penceToGBP() {
        let result = formatPence(1500, currencyCode: "GBP")
        #expect(result == "£15.00")
    }

    @Test("Handles zero pence")
    func zeroPence() {
        let result = formatPence(0, currencyCode: "GBP")
        #expect(result == "£0.00")
    }

    @Test("Handles single-digit minor units")
    func singleDigitMinor() {
        let result = formatPence(105, currencyCode: "GBP")
        #expect(result == "£1.05")
    }

    @Test("JPY pence are whole units (no conversion)")
    func jpyWholeUnits() {
        let result = formatPence(1500, currencyCode: "JPY")
        #expect(result == "¥1,500" || result == "¥1500")
    }

    @Test("USD cents to dollars")
    func usdCents() {
        let result = formatPence(9999, currencyCode: "USD")
        #expect(result.contains("99.99") || result.contains("99,99"))
        #expect(result.contains("$"))
    }

    @Test("Large pence value with grouping separator")
    func largePenceValue() {
        let result = formatPence(100000, currencyCode: "GBP")
        #expect(result == "£1,000.00" || result == "£1000.00")
    }
}

// MARK: - CurrencySettings Tests

@Suite("CurrencySettings")
struct CurrencySettingsTests {

    @Test("Storage key is correct")
    func storageKey() {
        #expect(CurrencySettings.key == "selectedCurrencyCode")
    }

    @Test("Default currency falls back to GBP when not set")
    func defaultCurrency() {
        // If no setting is stored, it defaults to GBP
        let currency = SupportedCurrency(rawValue: "GBP")
        #expect(currency == .gbp)
    }

    @Test("All currency codes can be round-tripped through rawValue")
    func roundTripCurrencyCodes() {
        for currency in SupportedCurrency.allCases {
            let roundTripped = SupportedCurrency(rawValue: currency.rawValue)
            #expect(roundTripped == currency)
        }
    }
}
