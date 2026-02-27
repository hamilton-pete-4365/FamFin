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
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search accounts"
            )
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
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
