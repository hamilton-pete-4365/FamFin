import SwiftUI

/// Searchable sheet for selecting a budget category.
///
/// Shows a flat list of categories with their group name on the right, preserving
/// the same order as the budget view. The system search bar filters by category or group name.
struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let categories: [Category]
    let groupedCategories: [CategoryGroup]
    let toBudgetCategory: Category?
    let onSelect: (Category) -> Void

    @State private var searchText = ""

    /// Flat list of all categories with their parent group name, preserving group order.
    private var allRows: [(groupName: String, category: Category)] {
        var result: [(String, Category)] = []
        for group in groupedCategories {
            for sub in group.subcategories {
                let name = sub.parent?.name ?? "Other"
                result.append((name, sub))
            }
        }
        return result
    }

    /// Rows filtered by the current search text. Matches against category name or group name.
    private var displayRows: [(groupName: String, category: Category)] {
        guard !searchText.isEmpty else { return allRows }
        return allRows.filter {
            $0.category.name.localizedStandardContains(searchText) ||
            $0.groupName.localizedStandardContains(searchText)
        }
    }

    /// Whether the "To Budget" row should be visible given the current search.
    private var showToBudget: Bool {
        guard toBudgetCategory != nil else { return false }
        if searchText.isEmpty { return true }
        return toBudgetCategory!.name.localizedStandardContains(searchText)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField

                Divider()

                List {
                    if let tbc = toBudgetCategory, showToBudget {
                        categoryRow(
                            category: tbc,
                            groupName: nil,
                            displayName: "\u{1F4B0} To Budget"
                        )
                    }

                    if !searchText.isEmpty && displayRows.isEmpty && !showToBudget {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        ForEach(displayRows, id: \.category.id) { row in
                            categoryRow(category: row.category, groupName: row.groupName)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Category")
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

            TextField("Search categories", text: $searchText)
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

    // MARK: - Category Row

    private func categoryRow(
        category: Category,
        groupName: String?,
        displayName: String? = nil
    ) -> some View {
        Button {
            onSelect(category)
            dismiss()
        } label: {
            HStack {
                Text(displayName ?? "\(category.emoji) \(category.name)")
                    .foregroundStyle(.primary)
                Spacer()
                if let group = groupName {
                    Text(group)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(.primary)
    }
}
