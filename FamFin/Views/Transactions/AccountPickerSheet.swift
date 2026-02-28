import SwiftUI

/// Searchable sheet for selecting an account, grouped by Budget and Tracking.
///
/// Optionally excludes a specific account (e.g. the "From" account in a transfer picker).
struct AccountPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let accounts: [Account]
    var excludeAccount: Account? = nil
    let onSelect: (Account) -> Void

    @State private var searchText = ""

    private var displayAccounts: [Account] {
        accounts.filter { account in
            if let exclude = excludeAccount,
               account.persistentModelID == exclude.persistentModelID {
                return false
            }
            return true
        }
    }

    private var budgetAccounts: [Account] {
        let filtered = displayAccounts.filter { $0.isBudget }
        guard !searchText.isEmpty else { return filtered }
        return filtered.filter { $0.name.localizedStandardContains(searchText) }
    }

    private var trackingAccounts: [Account] {
        let filtered = displayAccounts.filter { !$0.isBudget }
        guard !searchText.isEmpty else { return filtered }
        return filtered.filter { $0.name.localizedStandardContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField

                Divider()

                List {
                    if !budgetAccounts.isEmpty {
                        Section("Budget Accounts") {
                            ForEach(budgetAccounts) { account in
                                accountButton(account)
                            }
                        }
                    }
                    if !trackingAccounts.isEmpty {
                        Section("Tracking Accounts") {
                            ForEach(trackingAccounts) { account in
                                accountButton(account)
                            }
                        }
                    }

                    if budgetAccounts.isEmpty && trackingAccounts.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search accounts", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

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

    private func accountButton(_ account: Account) -> some View {
        Button {
            onSelect(account)
            dismiss()
        } label: {
            HStack {
                Text(account.name)
                    .foregroundStyle(.primary)
                Spacer()
                Text(account.type.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(.primary)
        .accessibilityLabel("\(account.name), \(account.type.rawValue)")
    }
}
