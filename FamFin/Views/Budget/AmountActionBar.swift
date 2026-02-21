import SwiftUI

/// Thin action bar between the budget list and the keypad.
///
/// Shows contextual actions for the currently focused budget category:
/// Quick Fill (opens suggestions popover) and Details (navigates to category detail).
///
/// The popover content is injected via `@ViewBuilder` so the popover anchors
/// directly to the Quick Fill button rather than the entire bar.
struct AmountActionBar<PopoverContent: View>: View {
    @Binding var showQuickFill: Bool
    let onDetails: () -> Void
    @ViewBuilder let popoverContent: () -> PopoverContent

    @State private var maxWidth: CGFloat = 0

    var body: some View {
        HStack {
            actionButton("Quick Fill", systemImage: "sparkles") {
                showQuickFill = true
            }
            .popover(isPresented: $showQuickFill, arrowEdge: .bottom) {
                popoverContent()
                    .presentationCompactAdaptation(.popover)
            }

            Spacer()

            actionButton("Details", systemImage: "chevron.right", iconTrailing: true) {
                onDetails()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// Builds a pill-shaped action button with a shared minimum width so both buttons match.
    private func actionButton(
        _ title: String,
        systemImage: String,
        iconTrailing: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if !iconTrailing {
                    Image(systemName: systemImage)
                }
                Text(title)
                if iconTrailing {
                    Image(systemName: systemImage)
                }
            }
            .font(.subheadline)
            .bold()
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minWidth: maxWidth)
            .background(Color.accentColor.opacity(0.15))
            .clipShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            if width > maxWidth {
                maxWidth = width
            }
        }
    }
}

// MARK: - Preview

#Preview("Amount Action Bar") {
    @Previewable @State var showQuickFill = false

    VStack {
        Spacer()
        AmountActionBar(
            showQuickFill: $showQuickFill,
            onDetails: {}
        ) {
            Text("Quick Fill Content")
                .padding()
        }
    }
}
