import SwiftUI
import SwiftData

/// Pushed view for finding or creating a payee.
///
/// Starts blank with the keyboard ready. As the user types, matching payees
/// appear alphabetically. Selecting an existing payee calls `onSelect`;
/// typing a new name and tapping "Use [name]" calls `onCustomPayee`.
struct PayeeSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Payee.name) private var allPayees: [Payee]

    let onSelect: (Payee) -> Void
    let onCustomPayee: (String) -> Void

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredPayees: [Payee] {
        guard !searchText.isEmpty else { return [] }
        return allPayees.filter { $0.name.localizedStandardContains(searchText) }
    }

    /// Whether the search text exactly matches an existing payee name.
    private var hasExactMatch: Bool {
        allPayees.contains { $0.name.caseInsensitiveCompare(searchText) == .orderedSame }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField

            Divider()

            List {
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
            .overlay {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "Search for a payee",
                        systemImage: "magnifyingglass",
                        description: Text("Start typing to find or create a payee")
                    )
                }
            }
        }
        .navigationTitle("Payee")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Skip the keyboard slide-up animation so it appears instantly
            // once the navigation push completes.
            let transaction = SwiftUI.Transaction(animation: nil)
            withTransaction(transaction) {
                isSearchFocused = true
            }
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search or enter payee", text: $searchText)
                .focused($isSearchFocused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit {
                    if !searchText.isEmpty && !hasExactMatch {
                        onCustomPayee(searchText)
                        dismiss()
                    }
                }

            if !searchText.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") {
                    searchText = ""
                }
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

// MARK: - Payee Row

/// Displays a single payee with their last-used category.
private struct PayeeRow: View {
    let payee: Payee

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(payee.name)

            if let cat = payee.lastUsedCategory {
                Text("\(cat.emoji) \(cat.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
