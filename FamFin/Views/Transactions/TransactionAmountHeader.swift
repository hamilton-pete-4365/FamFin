import SwiftUI

/// Large amount display at the top of the Add/Edit Transaction sheet.
///
/// When the keypad is active, shows the engine's live display string.
/// When inactive, shows the stored amount. Tappable to re-open the keypad.
struct TransactionAmountHeader: View {
    let viewModel: TransactionFormViewModel
    let currencyCode: String
    let onTapToEdit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Formatted amount string for display when the keypad is not active.
    private var staticDisplayString: String {
        let base = formatPence(viewModel.amountPence, currencyCode: currencyCode)
        return "\(viewModel.amountSignPrefix)\(base)"
    }

    /// The pence value currently shown — uses live engine value when keypad is active.
    private var displayPence: Int {
        viewModel.isKeypadVisible ? viewModel.engine.primaryDisplayPence : viewModel.amountPence
    }

    /// Formatted amount string that updates live during keypad entry.
    ///
    /// During maths the sign prefix is omitted — the colour already communicates
    /// expense/income, and mixing "-" with math operators ("+ £15") is confusing.
    private var liveDisplayString: String {
        let base = viewModel.engine.displayString
        let prefix = viewModel.engine.hasExpression ? "" : signPrefix
        return "\(prefix)\(base)"
    }

    /// Sign prefix based on the currently displayed pence value.
    private var signPrefix: String {
        guard displayPence > 0 else { return "" }
        switch viewModel.type {
        case .expense: return "-"
        case .income: return "+"
        case .transfer: return ""
        }
    }

    /// Amount colour based on the currently displayed pence value.
    private var displayColor: Color {
        guard displayPence > 0 else { return .secondary }
        switch viewModel.type {
        case .expense: return .red
        case .income: return .green
        case .transfer: return .primary
        }
    }

    /// Pre-calculated height for two `.title2` rows + spacing, so the area
    /// stays stable when switching between single-row and maths mode.
    private var twoRowHeight: CGFloat {
        let lineHeight = UIFont.preferredFont(forTextStyle: .title2).lineHeight
        return lineHeight * 2 + 4 // 4pt VStack spacing
    }

    /// Whether the engine has a pending math expression.
    private var hasExpression: Bool {
        viewModel.isKeypadVisible && viewModel.engine.hasExpression
    }

    /// Font for each amount row — shrinks to title2 during maths so both rows fit.
    private var amountFont: Font {
        hasExpression ? .title2.weight(.medium) : .largeTitle.weight(.medium)
    }

    var body: some View {
        VStack(spacing: 4) {
            Button {
                if !viewModel.isKeypadVisible {
                    onTapToEdit()
                }
            } label: {
                HStack {
                    Spacer()

                    VStack(spacing: 4) {
                        Text(viewModel.isKeypadVisible ? liveDisplayString : staticDisplayString)
                            .font(amountFont)
                            .monospacedDigit()
                            .foregroundStyle(displayColor)
                            .contentTransition(reduceMotion ? .identity : .numericText())

                        if hasExpression {
                            Text(viewModel.engine.expressionDisplayString ?? "")
                                .font(amountFont)
                                .monospacedDigit()
                                .foregroundStyle(displayColor)
                                .transition(.opacity)
                        }
                    }
                    // Reserve enough height for the two-row maths state so the
                    // header never changes size when an expression appears.
                    .frame(minHeight: twoRowHeight)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Amount: \(staticDisplayString)")
            .accessibilityHint(viewModel.isKeypadVisible ? "Editing amount" : "Double tap to edit amount")

            Text("Tap to change amount")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .opacity(viewModel.isKeypadVisible ? 0 : 1)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Color(.opaqueSeparator)
                .frame(height: 0.5)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: viewModel.type)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: viewModel.isKeypadVisible)
    }
}
