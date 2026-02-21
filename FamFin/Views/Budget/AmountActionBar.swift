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
            .frame(width: 120)

            Spacer()

            Button("Details", systemImage: "chevron.right") {
                onDetails()
            }
            .labelStyle(.titleAndIcon)
            .frame(width: 120)
        }
        .font(.subheadline)
        .bold()
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(.accentColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
