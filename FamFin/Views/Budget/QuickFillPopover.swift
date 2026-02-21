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
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Last Month")
            HStack(spacing: 8) {
                quickFillButton(label: "Budgeted", amount: lastBudgeted)
                quickFillButton(label: "Spent", amount: lastSpent)
            }

            sectionHeader("12-Month Average")
            HStack(spacing: 8) {
                quickFillButton(label: "Budgeted", amount: avgBudgeted)
                quickFillButton(label: "Spent", amount: avgSpent)
            }

            if let goal = firstGoalTarget {
                sectionHeader("Goal")
                goalButton(name: goal.name, amount: goal.amount)
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    // MARK: - Row Builders

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption2)
            .textCase(.uppercase)
            .foregroundStyle(.tertiary)
            .accessibilityAddTraits(.isHeader)
    }

    private func quickFillButton(label: String, amount: Decimal) -> some View {
        let isZero = amount == .zero

        return Button {
            onSelectAmount(amount)
        } label: {
            VStack(spacing: 4) {
                Text(formatGBP(amount, currencyCode: currencyCode))
                    .font(.subheadline)
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(isZero ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.accentColor))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(isZero ? .tertiary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isZero ? Color(.quaternarySystemFill) : Color.accentColor.opacity(0.1))
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isZero)
        .accessibilityLabel("\(label): \(formatGBP(amount, currencyCode: currencyCode))")
        .accessibilityHint(isZero ? "" : "Double tap to fill budget with this amount")
    }

    private func goalButton(name: String, amount: Decimal) -> some View {
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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name) target: \(formatGBP(amount, currencyCode: currencyCode))")
        .accessibilityHint("Double tap to fill budget with this amount")
    }
}
