import SwiftUI

/// Thin action bar between the budget list and the keypad.
///
/// Shows contextual actions for the currently focused budget category:
/// Quick Fill (opens suggestions popover) and Details (navigates to category detail).
struct AmountActionBar: View {
    let onQuickFill: () -> Void
    let onDetails: () -> Void

    var body: some View {
        HStack {
            Button("Quick Fill", systemImage: "sparkles") {
                onQuickFill()
            }
            .font(.subheadline)

            Spacer()

            Button("Details", systemImage: "chevron.right") {
                onDetails()
            }
            .font(.subheadline)
            .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

// MARK: - Preview

#Preview("Amount Action Bar") {
    VStack {
        Spacer()
        AmountActionBar(
            onQuickFill: {},
            onDetails: {}
        )
    }
}
