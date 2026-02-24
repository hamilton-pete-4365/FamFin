import SwiftUI

/// Custom 4×4 keypad for ATM-style amount entry with basic math.
///
/// Layout:
/// ```
/// ┌──────┬──────┬──────┬──────┐
/// │  1   │  2   │  3   │  ⌫   │
/// ├──────┼──────┼──────┼──────┤
/// │  4   │  5   │  6   │  +   │
/// ├──────┼──────┼──────┼──────┤
/// │  7   │  8   │  9   │  −   │
/// ├──────┼──────┼──────┼──────┤
/// │  ✕   │  0   │  =   │ Done │
/// └──────┴──────┴──────┴──────┘
/// ```
struct AmountKeypad: View {
    let engine: AmountKeypadEngine
    let onCancel: () -> Void
    let onDone: (Decimal) -> Void

    @State private var tapCount = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            // Row 1: 1 2 3 ⌫
            digitKey(1)
            digitKey(2)
            digitKey(3)
            iconKey("delete.backward", style: .dismiss) {
                engine.backspaceTapped()
            }
            .accessibilityLabel("Delete")
            .accessibilityHint("Removes last digit")

            // Row 2: 4 5 6 +
            digitKey(4)
            digitKey(5)
            digitKey(6)
            operatorKey("+") {
                engine.plusTapped()
            }
            .accessibilityLabel("Plus")
            .accessibilityHint("Adds to current amount")

            // Row 3: 7 8 9 −
            digitKey(7)
            digitKey(8)
            digitKey(9)
            operatorKey("−") {
                engine.minusTapped()
            }
            .accessibilityLabel("Minus")
            .accessibilityHint("Subtracts from current amount")

            // Row 4: ✕ 0 = Done
            iconKey("xmark", style: .dismiss) {
                onCancel()
            }
            .accessibilityLabel("Cancel")
            .accessibilityHint("Reverts to original amount and closes keypad")

            digitKey(0)

            operatorKey("=") {
                engine.equalsTapped()
            }
            .accessibilityLabel("Equals")
            .accessibilityHint("Calculates the result")

            doneKey()
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.bar)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.4), trigger: tapCount)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Amount keypad")
    }

    // MARK: - Key Builders

    private func digitKey(_ digit: Int) -> some View {
        Button {
            tapCount += 1
            engine.digitTapped(digit)
        } label: {
            Text("\(digit)")
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(KeypadButtonStyle(role: .digit))
        .accessibilityLabel(digitAccessibilityLabel(digit))
        .accessibilityHint("Enters digit \(digit)")
    }

    private func operatorKey(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            tapCount += 1
            action()
        } label: {
            Text(label)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(KeypadButtonStyle(role: .operator))
    }

    private func iconKey(_ systemName: String, style: KeypadButtonStyle.Role, action: @escaping () -> Void) -> some View {
        Button {
            tapCount += 1
            action()
        } label: {
            Image(systemName: systemName)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(KeypadButtonStyle(role: style))
    }

    private func doneKey() -> some View {
        Button {
            tapCount += 1
            let amount = engine.doneTapped()
            onDone(amount)
        } label: {
            Text("Done")
                .font(.title3)
                .bold()
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(KeypadButtonStyle(role: .done))
        .accessibilityLabel("Done")
        .accessibilityHint("Saves amount and closes keypad")
    }

    // MARK: - Accessibility Helpers

    private func digitAccessibilityLabel(_ digit: Int) -> String {
        let words = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"]
        return words[digit]
    }
}

// MARK: - Keypad Button Style

/// Custom button style for keypad keys with role-based appearance.
///
/// Four distinct visual roles to make the keypad scannable at a glance:
/// - **digit**: Neutral fill — the primary surface for number input.
/// - **operator**: Tinted accent background — stands out as math actions (+, −, =).
/// - **dismiss**: Muted secondary text on minimal background — clearly "escape" actions (✕, ⌫).
/// - **done**: Solid accent background with white text — the primary action.
struct KeypadButtonStyle: ButtonStyle {
    enum Role {
        case digit
        case `operator`
        case dismiss
        case done
    }

    let role: Role

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .clipShape(.rect(cornerRadius: 10))
            .overlay {
                if role == .dismiss {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.separator, lineWidth: 1)
                }
            }
    }

    private var foregroundColor: some ShapeStyle {
        switch role {
        case .digit:
            return AnyShapeStyle(.primary)
        case .operator:
            return AnyShapeStyle(Color.accentColor)
        case .dismiss:
            return AnyShapeStyle(.secondary)
        case .done:
            return AnyShapeStyle(.white)
        }
    }

    @ViewBuilder
    private func backgroundColor(isPressed: Bool) -> some View {
        switch role {
        case .digit:
            Color(.systemFill)
                .opacity(isPressed ? 0.6 : 1)
        case .operator:
            Color.accentColor.opacity(isPressed ? 0.12 : 0.15)
        case .dismiss:
            Color(.quaternarySystemFill)
                .opacity(isPressed ? 0.6 : 1)
        case .done:
            Color.accentColor
                .opacity(isPressed ? 0.7 : 1)
        }
    }
}

// MARK: - Preview

#Preview("Amount Keypad") {
    @Previewable @State var engine = AmountKeypadEngine()

    VStack {
        Spacer()
        Text(engine.displayString)
            .font(.largeTitle)
            .monospacedDigit()
        if let expr = engine.expressionDisplayString {
            Text(expr)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        Spacer()
        AmountKeypad(
            engine: engine,
            onCancel: { engine.deactivate() },
            onDone: { _ in engine.deactivate() }
        )
    }
    .onAppear {
        engine.activate(currentPence: 0, currencyCode: "GBP")
    }
}
