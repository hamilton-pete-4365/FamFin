import Foundation
import Testing
@testable import FamFin

// MARK: - Digit Entry

@Suite("ATM-style digit entry")
struct DigitEntryTests {

    @Test("Typing digits builds a pence value")
    @MainActor func typingDigits() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(1)
        engine.digitTapped(5)
        engine.digitTapped(3)
        engine.digitTapped(6)

        #expect(engine.rawDigits == "1536")
        #expect(engine.displayPence == 1536)
    }

    @Test("Display string formats pence as currency")
    @MainActor func displayStringFormats() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(1)
        engine.digitTapped(5)
        engine.digitTapped(3)
        engine.digitTapped(6)

        #expect(engine.displayString == "£15.36")
    }

    @Test("Single digit shows as pence")
    @MainActor func singleDigit() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(5)

        #expect(engine.displayPence == 5)
        #expect(engine.displayString == "£0.05")
    }

    @Test("Leading zeros are stripped")
    @MainActor func leadingZeros() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(0)
        engine.digitTapped(0)
        engine.digitTapped(5)

        #expect(engine.rawDigits == "5")
        #expect(engine.displayPence == 5)
    }

    @Test("Max 12 digits enforced")
    @MainActor func maxDigits() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        for _ in 0..<15 {
            engine.digitTapped(9)
        }

        #expect(engine.rawDigits.count == 12)
        #expect(engine.rawDigits == "999999999999")
    }

    @Test("Zero into empty engine is no-op for rawDigits")
    @MainActor func zeroIntoEmpty() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(0)

        // Zero is stripped as a leading zero, rawDigits remains empty
        #expect(engine.rawDigits == "")
        #expect(engine.displayPence == 0)
    }
}

// MARK: - First Keystroke Replaces

@Suite("First keystroke replaces existing value")
struct FirstKeystrokeReplacesTests {

    @Test("First digit replaces existing value")
    @MainActor func firstDigitReplaces() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 1500, currencyCode: "GBP")

        engine.digitTapped(3)

        #expect(engine.rawDigits == "3")
        #expect(engine.displayPence == 3)
    }

    @Test("Subsequent digits append after first keystroke")
    @MainActor func subsequentDigitsAppend() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 1500, currencyCode: "GBP")

        engine.digitTapped(3)
        engine.digitTapped(0)
        engine.digitTapped(0)

        #expect(engine.rawDigits == "300")
        #expect(engine.displayPence == 300)
    }

    @Test("Activating with zero does not trigger replacement")
    @MainActor func activateWithZero() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(5)

        #expect(engine.rawDigits == "5")
    }
}

// MARK: - Backspace

@Suite("Backspace behaviour")
struct BackspaceTests {

    @Test("Backspace removes last digit")
    @MainActor func removesLastDigit() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(1)
        engine.digitTapped(5)
        engine.digitTapped(3)
        engine.digitTapped(6)
        engine.backspaceTapped()

        #expect(engine.rawDigits == "153")
        #expect(engine.displayPence == 153)
    }

    @Test("Backspace on empty is a no-op")
    @MainActor func emptyNoOp() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.backspaceTapped()

        #expect(engine.rawDigits == "")
        #expect(engine.displayPence == 0)
    }

    @Test("Backspace removes to empty")
    @MainActor func removesToEmpty() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(5)
        engine.backspaceTapped()

        #expect(engine.rawDigits == "")
        #expect(engine.displayPence == 0)
    }

    @Test("Backspace undoes operator when rawDigits empty during expression")
    @MainActor func undoesOperator() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(1)
        engine.digitTapped(5)
        engine.digitTapped(0)
        engine.plusTapped()

        // rawDigits is now empty, expression has firstOperand = 150
        #expect(engine.hasExpression)

        engine.backspaceTapped()

        // Should undo: restore 150 to rawDigits, clear expression
        #expect(engine.rawDigits == "150")
        #expect(!engine.hasExpression)
    }
}

// MARK: - Math Expressions

@Suite("Math expressions")
struct MathExpressionTests {

    @Test("Addition resolves correctly")
    @MainActor func addition() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(1)
        engine.digitTapped(5)
        engine.digitTapped(0)
        engine.plusTapped()
        engine.digitTapped(5)
        engine.digitTapped(0)
        engine.equalsTapped()

        #expect(engine.displayPence == 200)
        #expect(!engine.hasExpression)
    }

    @Test("Subtraction resolves correctly")
    @MainActor func subtraction() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(5)
        engine.digitTapped(0)
        engine.digitTapped(0)
        engine.minusTapped()
        engine.digitTapped(1)
        engine.digitTapped(5)
        engine.digitTapped(0)
        engine.equalsTapped()

        #expect(engine.displayPence == 350)
        #expect(!engine.hasExpression)
    }

    @Test("Chaining operations resolves left to right")
    @MainActor func chaining() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        // 100 + 50 + 30 = 180
        engine.digitTapped(1)
        engine.digitTapped(0)
        engine.digitTapped(0)
        engine.plusTapped()
        engine.digitTapped(5)
        engine.digitTapped(0)
        engine.plusTapped() // resolves 100 + 50 = 150, starts 150 + ?
        engine.digitTapped(3)
        engine.digitTapped(0)
        engine.equalsTapped() // resolves 150 + 30 = 180

        #expect(engine.displayPence == 180)
    }

    @Test("Mixed add and subtract")
    @MainActor func mixedOperations() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        // 500 + 200 - 100 = 600
        engine.digitTapped(5)
        engine.digitTapped(0)
        engine.digitTapped(0)
        engine.plusTapped()
        engine.digitTapped(2)
        engine.digitTapped(0)
        engine.digitTapped(0)
        engine.minusTapped() // resolves 500 + 200 = 700, starts 700 - ?
        engine.digitTapped(1)
        engine.digitTapped(0)
        engine.digitTapped(0)
        engine.equalsTapped() // resolves 700 - 100 = 600

        #expect(engine.displayPence == 600)
    }

    @Test("Subtraction result clamped to zero")
    @MainActor func clampedToZero() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        // 100 - 200 = 0 (clamped)
        engine.digitTapped(1)
        engine.digitTapped(0)
        engine.digitTapped(0)
        engine.minusTapped()
        engine.digitTapped(2)
        engine.digitTapped(0)
        engine.digitTapped(0)
        engine.equalsTapped()

        #expect(engine.displayPence == 0)
    }

    @Test("Plus with empty second operand resolves to first operand")
    @MainActor func emptySecondOperand() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(1)
        engine.digitTapped(5)
        engine.digitTapped(0)
        engine.plusTapped()
        engine.equalsTapped() // second operand is 0

        #expect(engine.displayPence == 150)
    }

    @Test("Equals without expression is a no-op")
    @MainActor func equalsWithoutExpression() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(5)
        engine.equalsTapped()

        #expect(engine.rawDigits == "5")
        #expect(engine.displayPence == 5)
    }

    @Test("Expression is active after plus")
    @MainActor func expressionActiveAfterPlus() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(1)
        engine.digitTapped(5)
        engine.digitTapped(0)
        engine.plusTapped()

        #expect(engine.hasExpression)
        #expect(engine.expression?.firstOperand == 150)
        #expect(engine.expression?.op == .add)
        #expect(engine.rawDigits == "")
    }
}

// MARK: - Expression Display String

@Suite("Expression display string")
struct ExpressionDisplayTests {

    @Test("Shows operation line during math, display shows first operand")
    @MainActor func formattedExpression() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(1)
        engine.digitTapped(5)
        engine.digitTapped(0)
        engine.plusTapped()
        engine.digitTapped(5)
        engine.digitTapped(0)

        // expressionDisplayString shows just the operation line
        let display = engine.expressionDisplayString
        #expect(display != nil)
        #expect(display!.contains("+"))
        #expect(display!.contains("0.50"))
        // Should NOT contain the first operand — that's in displayString
        #expect(!display!.contains("1.50"))

        // displayString shows the first operand (running total)
        #expect(engine.displayString.contains("1.50"))
    }

    @Test("Returns nil when no expression")
    @MainActor func nilWhenNoExpression() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(5)

        #expect(engine.expressionDisplayString == nil)
    }

    @Test("Shows minus symbol for subtraction")
    @MainActor func minusSymbol() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(5)
        engine.digitTapped(0)
        engine.digitTapped(0)
        engine.minusTapped()
        engine.digitTapped(1)
        engine.digitTapped(0)
        engine.digitTapped(0)

        let display = engine.expressionDisplayString
        #expect(display != nil)
        #expect(display!.contains("−"))
        #expect(display!.contains("1.00"))

        // displayString shows the first operand
        #expect(engine.displayString.contains("5.00"))
    }

    @Test("After equals, display shows result and expression clears")
    @MainActor func afterEquals() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(1)
        engine.digitTapped(0)
        engine.digitTapped(0)
        engine.digitTapped(0)
        engine.plusTapped()
        engine.digitTapped(5)
        engine.digitTapped(0)
        engine.digitTapped(0)
        engine.equalsTapped()

        // After =, result in displayString, no expression
        #expect(engine.displayString.contains("15.00"))
        #expect(engine.expressionDisplayString == nil)
    }

    @Test("Chaining: plus after expression shows updated total")
    @MainActor func chaining() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(1)
        engine.digitTapped(0)
        engine.digitTapped(0)
        engine.digitTapped(0)
        engine.plusTapped()
        engine.digitTapped(5)
        engine.digitTapped(0)
        engine.digitTapped(0)
        engine.plusTapped() // resolves 10.00 + 5.00 = 15.00, starts new +

        // displayString shows the resolved total (£15.00)
        #expect(engine.displayString.contains("15.00"))
        // expressionDisplayString shows the new empty operand
        #expect(engine.expressionDisplayString != nil)
        #expect(engine.expressionDisplayString!.contains("+"))
    }
}

// MARK: - Cancel

@Suite("Cancel behaviour")
struct CancelTests {

    @Test("Cancel returns original value")
    @MainActor func returnsOriginalValue() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 1500, currencyCode: "GBP")

        engine.digitTapped(2)
        engine.digitTapped(0)
        engine.digitTapped(0)
        engine.digitTapped(0)

        let originalValue = engine.cancelTapped()

        #expect(originalValue == Decimal(15))
    }

    @Test("Cancel deactivates the engine")
    @MainActor func deactivatesEngine() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 1500, currencyCode: "GBP")

        _ = engine.cancelTapped()

        #expect(!engine.isActive)
        #expect(engine.rawDigits == "")
    }

    @Test("Cancel from zero returns zero")
    @MainActor func cancelFromZero() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(5)
        let originalValue = engine.cancelTapped()

        #expect(originalValue == Decimal.zero)
    }
}

// MARK: - Done

@Suite("Done behaviour")
struct DoneTests {

    @Test("Done returns decimal amount")
    @MainActor func returnsDecimalAmount() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(1)
        engine.digitTapped(5)
        engine.digitTapped(3)
        engine.digitTapped(6)

        let amount = engine.doneTapped()

        #expect(amount == Decimal(string: "15.36"))
    }

    @Test("Done resolves pending expression")
    @MainActor func resolvesPendingExpression() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(1)
        engine.digitTapped(5)
        engine.digitTapped(0)
        engine.plusTapped()
        engine.digitTapped(5)
        engine.digitTapped(0)

        let amount = engine.doneTapped()

        #expect(amount == Decimal(2)) // 150 + 50 = 200 pence = £2.00
    }

    @Test("Done deactivates the engine")
    @MainActor func deactivatesEngine() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(5)
        _ = engine.doneTapped()

        #expect(!engine.isActive)
    }

    @Test("Done with empty input returns zero")
    @MainActor func emptyReturnsZero() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        let amount = engine.doneTapped()

        #expect(amount == Decimal.zero)
    }
}

// MARK: - Quick Fill Hints

@Suite("Quick Fill hints")
struct HintTests {

    @Test("Hint sets rawDigits from decimal amount")
    @MainActor func hintSetsDigits() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.applyHint(Decimal(string: "15.36")!)

        #expect(engine.rawDigits == "1536")
        #expect(engine.displayPence == 1536)
    }

    @Test("Next digit after hint replaces the hint value")
    @MainActor func digitAfterHintReplaces() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.applyHint(Decimal(string: "15.36")!)
        engine.digitTapped(3)

        #expect(engine.rawDigits == "3")
        #expect(engine.displayPence == 3)
    }

    @Test("Hint clears any pending expression")
    @MainActor func hintClearsExpression() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(1)
        engine.digitTapped(0)
        engine.digitTapped(0)
        engine.plusTapped()

        #expect(engine.hasExpression)

        engine.applyHint(Decimal(25))

        #expect(!engine.hasExpression)
        #expect(engine.rawDigits == "2500")
    }

    @Test("Hint handles negative amounts by taking absolute value")
    @MainActor func hintNegativeAmount() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.applyHint(Decimal(string: "-20.00")!)

        #expect(engine.rawDigits == "2000")
    }

    @Test("Hint with zero amount clears rawDigits")
    @MainActor func hintZero() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 1500, currencyCode: "GBP")

        engine.applyHint(Decimal.zero)

        #expect(engine.rawDigits == "")
        #expect(engine.displayPence == 0)
    }
}

// MARK: - JPY Currency

@Suite("JPY currency handling")
struct JPYTests {

    @Test("JPY uses no minor units")
    @MainActor func jpyNoMinorUnits() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "JPY")

        engine.digitTapped(1)
        engine.digitTapped(5)
        engine.digitTapped(0)
        engine.digitTapped(0)

        #expect(engine.displayPence == 1500)
        // JPY minorUnitMultiplier is 1, so decimalAmount == pence value
        #expect(engine.decimalAmount == Decimal(1500))
    }

    @Test("JPY done returns whole-unit Decimal")
    @MainActor func jpyDone() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "JPY")

        engine.digitTapped(5)
        engine.digitTapped(0)
        engine.digitTapped(0)

        let amount = engine.doneTapped()

        #expect(amount == Decimal(500))
    }

    @Test("JPY hint converts correctly")
    @MainActor func jpyHint() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "JPY")

        engine.applyHint(Decimal(1500))

        #expect(engine.rawDigits == "1500")
        #expect(engine.decimalAmount == Decimal(1500))
    }
}

// MARK: - Lifecycle

@Suite("Engine lifecycle")
struct LifecycleTests {

    @Test("Activate sets isActive to true")
    @MainActor func activateSetsActive() {
        let engine = AmountKeypadEngine()

        #expect(!engine.isActive)

        engine.activate(currentPence: 0, currencyCode: "GBP")

        #expect(engine.isActive)
    }

    @Test("Deactivate clears all state")
    @MainActor func deactivateClears() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 1500, currencyCode: "GBP")
        engine.digitTapped(3)
        engine.plusTapped()

        engine.deactivate()

        #expect(!engine.isActive)
        #expect(engine.rawDigits == "")
        #expect(!engine.hasExpression)
    }

    @Test("Reactivation starts fresh")
    @MainActor func reactivationFresh() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 1500, currencyCode: "GBP")
        engine.digitTapped(9)
        _ = engine.doneTapped()

        // Reactivate with different value
        engine.activate(currentPence: 500, currencyCode: "GBP")

        #expect(engine.rawDigits == "500")
        #expect(engine.displayPence == 500)
        #expect(engine.isActive)
        #expect(!engine.hasExpression)
    }

    @Test("Display string when inactive shows zero")
    @MainActor func inactiveDisplayString() {
        let engine = AmountKeypadEngine()

        #expect(engine.displayPence == 0)
        #expect(engine.displayString == "£0.00")
    }
}

// MARK: - Edge Cases

@Suite("Edge cases")
struct EdgeCaseTests {

    @Test("Digits out of range are ignored")
    @MainActor func outOfRangeDigits() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(-1)
        engine.digitTapped(10)

        #expect(engine.rawDigits == "")
    }

    @Test("Operator on empty input uses zero as first operand")
    @MainActor func operatorOnEmpty() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.plusTapped()

        #expect(engine.hasExpression)
        #expect(engine.expression?.firstOperand == 0)
    }

    @Test("Multiple backspaces past empty are safe")
    @MainActor func multipleBackspaces() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 0, currencyCode: "GBP")

        engine.digitTapped(5)
        engine.backspaceTapped()
        engine.backspaceTapped()
        engine.backspaceTapped()

        #expect(engine.rawDigits == "")
        #expect(engine.displayPence == 0)
    }

    @Test("First-keystroke-replaces applies to non-zero activation only")
    @MainActor func firstKeystrokeWithExistingValue() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 2500, currencyCode: "GBP")

        // First keystroke should replace, not append to "2500"
        engine.digitTapped(1)
        #expect(engine.rawDigits == "1")

        // Second keystroke appends
        engine.digitTapped(0)
        #expect(engine.rawDigits == "10")
    }

    @Test("Backspace after first-keystroke-replaces works correctly")
    @MainActor func backspaceAfterReplace() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 2500, currencyCode: "GBP")

        engine.digitTapped(3) // replaces "2500" with "3"
        engine.backspaceTapped() // removes "3"

        #expect(engine.rawDigits == "")
        #expect(engine.displayPence == 0)
    }

    @Test("Plus immediately after activation works")
    @MainActor func plusAfterActivation() {
        let engine = AmountKeypadEngine()
        engine.activate(currentPence: 1500, currencyCode: "GBP")

        // Plus should use current value (1500) as first operand
        engine.plusTapped()

        #expect(engine.hasExpression)
        #expect(engine.expression?.firstOperand == 1500)
    }
}
