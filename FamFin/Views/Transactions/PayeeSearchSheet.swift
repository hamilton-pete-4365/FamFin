import SwiftUI
import SwiftData

/// Full-screen searchable list of payees, sorted by most recent usage.
///
/// Selecting an existing payee calls `onSelect` with the `Payee` record,
/// allowing the caller to auto-fill the category from the payee's history.
/// Typing a new name and tapping "Use [name]" calls `onCustomPayee` with just the string.
struct PayeeSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Payee.lastUsedDate, order: .reverse) private var allPayees: [Payee]

    let onSelect: (Payee) -> Void
    let onCustomPayee: (String) -> Void

    @State private var searchText = ""

    private var filteredPayees: [Payee] {
        guard !searchText.isEmpty else { return allPayees }
        return allPayees.filter { $0.name.localizedStandardContains(searchText) }
    }

    /// Whether the search text exactly matches an existing payee name.
    private var hasExactMatch: Bool {
        allPayees.contains { $0.name.caseInsensitiveCompare(searchText) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            List {
                if !searchText.isEmpty && !hasExactMatch {
                    Button {
                        onCustomPayee(searchText)
                        dismiss()
                    } label: {
                        Label("Use \"\(searchText)\"", systemImage: "plus.circle")
                    }
                }

                ForEach(filteredPayees) { payee in
                    Button {
                        onSelect(payee)
                        dismiss()
                    } label: {
                        PayeeRow(payee: payee)
                    }
                    .tint(.primary)
                }
            }
            .listStyle(.plain)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search or enter payee"
            )
            .navigationTitle("Payee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Payee Row

/// Displays a single payee in the search list with their last-used category and recency.
private struct PayeeRow: View {
    let payee: Payee

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(payee.name)

                if let cat = payee.lastUsedCategory {
                    Text("\(cat.emoji) \(cat.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(payee.lastUsedDate, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }
}
