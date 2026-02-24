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
    private var liveDisplayString: String {
        let base = viewModel.engine.displayString
        return "\(signPrefix)\(base)"
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
                            .font(.largeTitle.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(displayColor)
                            .contentTransition(reduceMotion ? .identity : .numericText())

                        if viewModel.isKeypadVisible, let expr = viewModel.engine.expressionDisplayString {
                            Text(expr)
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .transition(.opacity)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Amount: \(staticDisplayString)")
            .accessibilityHint(viewModel.isKeypadVisible ? "Editing amount" : "Double tap to edit amount")

            if !viewModel.isKeypadVisible && viewModel.amountPence > 0 {
                Text("Tap to change amount")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, viewModel.isKeypadVisible ? 32 : 16)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: viewModel.type)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: viewModel.isKeypadVisible)
    }
}
