import SwiftUI

/// Searchable sheet for selecting a budget category, grouped by header parent.
///
/// Categories are shown in the same order as the budget view. The "To Budget" system
/// category appears at the top. When searching, the list flattens to filtered results.
struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let categories: [Category]
    let groupedCategories: [CategoryGroup]
    let toBudgetCategory: Category?
    let onSelect: (Category) -> Void

    @State private var searchText = ""

    private var isSearching: Bool { !searchText.isEmpty }

    private var searchResults: [Category] {
        guard isSearching else { return [] }
        var results: [Category] = []
        if let tbc = toBudgetCategory,
           tbc.name.localizedStandardContains(searchText) {
            results.append(tbc)
        }
        results.append(contentsOf: categories.filter {
            !$0.isSystem && $0.name.localizedStandardContains(searchText)
        })
        return results
    }

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    if searchResults.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        ForEach(searchResults) { category in
                            categoryButton(category)
                        }
                    }
                } else {
                    if let tbc = toBudgetCategory {
                        Section {
                            categoryButton(tbc, displayName: "\u{1F4B0} To Budget")
                        }
                    }

                    ForEach(groupedCategories) { group in
                        Section(group.headerName) {
                            ForEach(group.subcategories) { sub in
                                categoryButton(sub)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search categories"
            )
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func categoryButton(_ category: Category, displayName: String? = nil) -> some View {
        Button {
            onSelect(category)
            dismiss()
        } label: {
            Text(displayName ?? "\(category.emoji) \(category.name)")
                .foregroundStyle(.primary)
        }
        .tint(.primary)
        .accessibilityLabel(displayName ?? "\(category.emoji) \(category.name)")
    }
}
