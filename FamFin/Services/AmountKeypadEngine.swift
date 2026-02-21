import Foundation

/// Pure logic engine for ATM-style amount entry with basic math expressions.
///
/// Manages digit input, `+`/`-` math, cancel/done lifecycle, and Quick Fill hints.
/// Designed to be the single source of truth for the custom keypad UI. Fully unit-testable.
///
/// ## ATM-Style Entry
/// Digits build from the right: typing "1536" produces 1536 minor units (£15.36 in GBP).
/// No decimal point is needed — the currency's minor unit multiplier handles formatting.
///
/// ## Math Expressions
/// Supports one pending `+` or `-` operation at a time. Chaining resolves the current
/// expression before starting the next (e.g. `100 + 50 + 30` resolves `150 + 30 = 180`).
/// Results are clamped to zero — budgets cannot be negative.
@Observable @MainActor
final class AmountKeypadEngine {

    // MARK: - Public State

    /// The raw digit string for the current operand (e.g. "1536" for £15.36).
    private(set) var rawDigits: String = ""

    /// Non-nil when a math expression is in progress.
    private(set) var expression: Expression? = nil

    /// Whether the keypad is currently active (visible).
    private(set) var isActive: Bool = false

    /// The currency code used for display formatting.
    var currencyCode: String = "GBP"

    // MARK: - Private State

    /// Backup of rawDigits at activation time, used for cancel/revert.
    private var previousDigits: String = ""

    /// Whether the user has typed since the keypad was activated.
    /// Used for first-keystroke-replaces behaviour.
    private var hasTyped: Bool = false

    /// The rawDigits value set by the last hint, for replacement detection.
    private var hintDigits: String = ""

    /// Whether the next digit tap should replace the current value.
    /// True after activation with a non-zero value, and after a hint is applied.
    private var shouldReplaceOnNextDigit: Bool = false

    // MARK: - Expression Model

    /// Represents a pending math operation.
    struct Expression: Equatable {
        var firstOperand: Int
        var op: Operator

        enum Operator: Equatable {
            case add
            case subtract

            var symbol: String {
                switch self {
                case .add: return "+"
                case .subtract: return "−"
                }
            }
        }
    }

    // MARK: - Computed Properties

    /// Current operand value in minor units (pence/cents).
    var displayPence: Int {
        Int(rawDigits) ?? 0
    }

    /// The pence value shown in the main budgeted column.
    ///
    /// During math: the first operand (running total so far).
    /// Otherwise: the current operand being typed.
    var primaryDisplayPence: Int {
        expression?.firstOperand ?? displayPence
    }

    /// Formatted currency string for the main budgeted column.
    ///
    /// During math: shows the running total (first operand).
    /// Otherwise: shows the current operand being typed.
    var displayString: String {
        formatPence(primaryDisplayPence, currencyCode: currencyCode)
    }

    /// Current operand converted to major-unit Decimal for saving.
    var decimalAmount: Decimal {
        let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
        return Decimal(displayPence) / Decimal(currency.minorUnitMultiplier)
    }

    /// Whether a math expression is currently in progress.
    var hasExpression: Bool {
        expression != nil
    }

    /// The current math operation line for display below the main amount.
    ///
    /// Returns something like `"+ £5.00"` when a math expression is active,
    /// or `nil` when there is no expression.
    var expressionDisplayString: String? {
        guard let expression else { return nil }

        let operandFormatted = formatPence(displayPence, currencyCode: currencyCode)
        return "\(expression.op.symbol)  \(operandFormatted)"
    }

    // MARK: - Lifecycle

    /// Activate the keypad for editing an amount.
    ///
    /// - Parameters:
    ///   - currentPence: The current value in minor units (e.g. 1536 for £15.36).
    ///   - currencyCode: The ISO currency code (e.g. "GBP").
    func activate(currentPence: Int, currencyCode: String) {
        self.currencyCode = currencyCode
        rawDigits = currentPence > 0 ? "\(currentPence)" : ""
        previousDigits = rawDigits
        hasTyped = false
        hintDigits = ""
        shouldReplaceOnNextDigit = currentPence > 0
        expression = nil
        isActive = true
    }

    /// Deactivate the keypad, clearing all state.
    func deactivate() {
        rawDigits = ""
        previousDigits = ""
        hasTyped = false
        hintDigits = ""
        shouldReplaceOnNextDigit = false
        expression = nil
        isActive = false
    }

    // MARK: - Digit Input

    /// Process a digit key tap (0–9).
    func digitTapped(_ digit: Int) {
        guard (0...9).contains(digit) else { return }

        // First keystroke after activation or hint replaces the entire value
        if shouldReplaceOnNextDigit {
            rawDigits = ""
            shouldReplaceOnNextDigit = false
            hasTyped = true
            hintDigits = ""
        }

        if !hasTyped {
            hasTyped = true
        }

        let candidate = rawDigits + "\(digit)"
        rawDigits = sanitise(candidate)
    }

    /// Process a backspace key tap.
    func backspaceTapped() {
        if !rawDigits.isEmpty {
            rawDigits = String(rawDigits.dropLast())
        } else if let expr = expression {
            // Undo the operator: restore first operand, clear expression
            rawDigits = expr.firstOperand > 0 ? "\(expr.firstOperand)" : ""
            expression = nil
            // Keep hasTyped true so further digits append
        }
    }

    // MARK: - Math Operations

    /// Process a plus key tap.
    func plusTapped() {
        beginOperation(.add)
    }

    /// Process a minus key tap.
    func minusTapped() {
        beginOperation(.subtract)
    }

    /// Process an equals key tap — resolves the current expression.
    func equalsTapped() {
        guard expression != nil else { return }
        resolveExpression()
    }

    // MARK: - Finalisation

    /// Process the Done key — resolves any pending expression and returns the final amount.
    ///
    /// - Returns: The resolved amount in major units as a Decimal.
    @discardableResult
    func doneTapped() -> Decimal {
        if expression != nil {
            resolveExpression()
        }
        let result = decimalAmount
        deactivate()
        return result
    }

    /// Process the Cancel key — reverts to the original value.
    ///
    /// - Returns: The original amount in major units as a Decimal, or `nil` if the original was zero.
    @discardableResult
    func cancelTapped() -> Decimal? {
        let originalPence = Int(previousDigits) ?? 0
        let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
        let result = Decimal(originalPence) / Decimal(currency.minorUnitMultiplier)
        deactivate()
        return result
    }

    // MARK: - Quick Fill Hints

    /// Apply a Quick Fill hint amount.
    ///
    /// Converts the Decimal to minor units and sets it as the current value.
    /// The next digit tap will replace this value (first-keystroke-replaces).
    func applyHint(_ amount: Decimal) {
        let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
        let multiplier = Decimal(currency.minorUnitMultiplier)
        let absAmount = amount < 0 ? -amount : amount
        let minorUnits = NSDecimalNumber(decimal: absAmount * multiplier).intValue
        let digits = minorUnits > 0 ? String("\(minorUnits)".prefix(8)) : ""

        // Clear any pending expression when applying a hint
        expression = nil
        hintDigits = digits
        rawDigits = digits
        hasTyped = true
        shouldReplaceOnNextDigit = !digits.isEmpty
    }

    // MARK: - Private Helpers

    /// Start a math operation, resolving any existing expression first (chaining).
    private func beginOperation(_ op: Expression.Operator) {
        if !hasTyped {
            hasTyped = true
            hintDigits = ""
        }
        shouldReplaceOnNextDigit = false

        // If an expression is already pending, resolve it first (chaining)
        if expression != nil {
            resolveExpression()
        }

        let operand = displayPence
        expression = Expression(firstOperand: operand, op: op)
        rawDigits = ""
    }

    /// Resolve the current expression and set rawDigits to the result.
    private func resolveExpression() {
        guard let expr = expression else { return }

        let secondOperand = displayPence
        let result: Int

        switch expr.op {
        case .add:
            result = expr.firstOperand + secondOperand
        case .subtract:
            result = max(0, expr.firstOperand - secondOperand) // clamp to zero
        }

        rawDigits = result > 0 ? "\(result)" : ""
        rawDigits = sanitise(rawDigits)
        expression = nil
    }

    /// Strip leading zeros and cap at 12 digits (covers up to £99,999,999.99).
    private func sanitise(_ digits: String) -> String {
        let cleaned = digits.filter { $0.isNumber }
        let trimmed = String(cleaned.drop(while: { $0 == "0" }))
        return String(trimmed.prefix(12))
    }
}
