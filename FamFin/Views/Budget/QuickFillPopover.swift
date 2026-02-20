import SwiftUI

/// Lightweight popover showing historical budget data and goal targets as tappable quick-fill options.
///
/// Replaces the heavier `QuickFillSheet` (which used a half-height sheet with NavigationStack).
/// Presented as a `.popover` anchored to the Quick Fill button in the action bar.
struct QuickFillPopover: View {
    let category: Category
    let month: Date
    let goals: [SavingsGoal]
    let currencyCode: String
    let onSelectAmount: (Decimal) -> Void

    // MARK: - Historical Data

    private var lastMonth: Date? {
        Calendar.current.date(byAdding: .month, value: -1, to: month)
    }

    private var lastBudgeted: Decimal {
        lastMonth.map { category.budgeted(in: $0) } ?? .zero
    }

    private var lastSpent: Decimal {
        lastMonth.map { -category.activity(in: $0) } ?? .zero
    }

    private var avgBudgeted: Decimal {
        category.averageMonthlyBudgeted(before: month, months: 12)
    }

    private var avgSpent: Decimal {
        category.averageMonthlySpending(before: month, months: 12)
    }

    private var firstGoalTarget: (name: String, amount: Decimal)? {
        for goal in goals {
            if let monthly = goal.monthlyTarget(through: month), monthly > 0 {
                return (goal.name, monthly)
            }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Last Month")
            quickFillRow(label: "Budgeted", amount: lastBudgeted)
            quickFillRow(label: "Spent", amount: lastSpent)

            Divider()
                .padding(.vertical, 4)

            sectionHeader("12-Month Average")
            quickFillRow(label: "Budgeted", amount: avgBudgeted)
            quickFillRow(label: "Spent", amount: avgSpent)

            if let goal = firstGoalTarget {
                Divider()
                    .padding(.vertical, 4)

                sectionHeader("Goal")
                goalRow(name: goal.name, amount: goal.amount)
            }
        }
        .padding(12)
        .frame(width: 260)
    }

    // MARK: - Row Builders

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption2)
            .textCase(.uppercase)
            .foregroundStyle(.tertiary)
            .padding(.bottom, 4)
            .padding(.top, 4)
            .accessibilityAddTraits(.isHeader)
    }

    private func quickFillRow(label: String, amount: Decimal) -> some View {
        let isZero = amount == .zero

        return Button {
            onSelectAmount(amount)
        } label: {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(isZero ? .tertiary : .primary)
                Spacer()
                Text(formatGBP(amount, currencyCode: currencyCode))
                    .font(.subheadline)
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(isZero ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.accentColor))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isZero)
        .accessibilityLabel("\(label): \(formatGBP(amount, currencyCode: currencyCode))")
        .accessibilityHint(isZero ? "" : "Double tap to fill budget with this amount")
    }

    private func goalRow(name: String, amount: Decimal) -> some View {
        Button {
            onSelectAmount(amount)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.caption)
                    .foregroundStyle(.purple)
                    .accessibilityHidden(true)
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Text(formatGBP(amount, currencyCode: currencyCode))
                    .font(.subheadline)
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name) target: \(formatGBP(amount, currencyCode: currencyCode))")
        .accessibilityHint("Double tap to fill budget with this amount")
    }
}
