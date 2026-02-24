import SwiftUI

/// Reusable tappable row for selection fields (payee, account, category).
///
/// Displays a label, the current value (or a placeholder if nothing is selected),
/// and a trailing chevron to indicate the row opens a picker sheet.
struct PickerRow: View {
    let label: String
    let value: String?
    let placeholder: String
    let systemImage: String
    var emoji: String? = nil
    var isRequired: Bool = true

    var body: some View {
        HStack {
            if let emoji {
                Text(emoji)
                    .font(.title3)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            Text(label)
                .foregroundStyle(.primary)

            Spacer()

            Text(value ?? placeholder)
                .foregroundStyle(value == nil ? .tertiary : .secondary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.accentColor)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(value != nil ? "\(label): \(value!)" : "\(label): \(placeholder)")
        .accessibilityHint("Double tap to choose")
    }
}
