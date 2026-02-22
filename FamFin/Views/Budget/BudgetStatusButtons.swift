import SwiftUI

/// Full-width pill-style status buttons shown between the month selector and the category list.
///
/// Up to two pills can appear:
/// - **Green "To Budget"** — informational, shows unallocated money remaining.
/// - **Red "Overbudgeted"** — tappable, opens a fix-it sheet to reduce category budgets.
/// - **Red "Overspent"** — tappable, opens a fix-it sheet to move money between categories.
///
/// When fully allocated with no overspending, no pills appear (the ideal state).
struct BudgetStatusButtons: View {
    let toBudgetAmount: Decimal
    let isOverbudgeted: Bool
    let overbudgetedAmount: Decimal
    let overspentCount: Int
    let currencyCode: String
    let onFixOverbudgeted: () -> Void
    let onFixOverspent: () -> Void

    var body: some View {
        let showToBudget = toBudgetAmount > 0
        let showOverbudgeted = isOverbudgeted
        let showOverspent = overspentCount > 0

        if showToBudget || showOverbudgeted || showOverspent {
            VStack(spacing: 8) {
                // Green "To Budget" (non-tappable, informational)
                if showToBudget {
                    informationalPill(
                        text: "\(formatGBP(toBudgetAmount, currencyCode: currencyCode)) left to budget",
                        color: .accentColor
                    )
                    .accessibilityLabel("\(formatGBP(toBudgetAmount, currencyCode: currencyCode)) left to budget")
                }

                // Red "Over budget" (tappable)
                if showOverbudgeted {
                    tappablePill(
                        text: "\(formatGBP(overbudgetedAmount, currencyCode: currencyCode)) over budget",
                        action: onFixOverbudgeted
                    )
                    .accessibilityLabel("\(formatGBP(overbudgetedAmount, currencyCode: currencyCode)) over budget")
                    .accessibilityHint("Double tap to fix")
                }

                // Red "Overspent" (tappable)
                if showOverspent {
                    tappablePill(
                        text: "\(overspentCount) \(overspentCount == 1 ? "category" : "categories") overspent",
                        action: onFixOverspent
                    )
                    .accessibilityLabel("\(overspentCount) \(overspentCount == 1 ? "category" : "categories") overspent")
                    .accessibilityHint("Double tap to fix")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Pill Views

    private func informationalPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.subheadline)
            .bold()
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.15))
            .clipShape(.rect(cornerRadius: 10))
    }

    private func tappablePill(text: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 4) {
                // Invisible chevron to balance the trailing one, keeping text centred
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .bold()
                    .hidden()
                    .accessibilityHidden(true)

                Spacer()

                Text(text)
                    .font(.subheadline)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .bold()
            }
            .foregroundStyle(.red.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.red.opacity(0.08))
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("All states") {
    VStack(spacing: 24) {
        // Green only
        BudgetStatusButtons(
            toBudgetAmount: 500,
            isOverbudgeted: false,
            overbudgetedAmount: 0,
            overspentCount: 0,
            currencyCode: "GBP",
            onFixOverbudgeted: {},
            onFixOverspent: {}
        )

        Divider()

        // Red overbudgeted only
        BudgetStatusButtons(
            toBudgetAmount: 0,
            isOverbudgeted: true,
            overbudgetedAmount: 50,
            overspentCount: 0,
            currencyCode: "GBP",
            onFixOverbudgeted: {},
            onFixOverspent: {}
        )

        Divider()

        // Green + overspent
        BudgetStatusButtons(
            toBudgetAmount: 200,
            isOverbudgeted: false,
            overbudgetedAmount: 0,
            overspentCount: 2,
            currencyCode: "GBP",
            onFixOverbudgeted: {},
            onFixOverspent: {}
        )

        Divider()

        // Two red pills
        BudgetStatusButtons(
            toBudgetAmount: 0,
            isOverbudgeted: true,
            overbudgetedAmount: 75,
            overspentCount: 3,
            currencyCode: "GBP",
            onFixOverbudgeted: {},
            onFixOverspent: {}
        )
    }
    .padding()
}
