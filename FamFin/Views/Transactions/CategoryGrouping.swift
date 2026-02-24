import SwiftUI

/// A group of subcategories under a single header, used for grouped display in pickers.
struct CategoryGroup: Identifiable {
    let headerName: String
    let subcategories: [Category]
    var id: String { headerName }
}

/// Groups visible subcategories under their header parents, preserving sort order.
///
/// Excludes the "To Budget" system category (shown separately at the top of pickers).
/// Returns groups ordered by header `sortOrder`, with an "Other" group for orphan categories.
func buildCategoryGroups(from categories: [Category]) -> [CategoryGroup] {
    // Collect unique headers in order
    var seen = Set<String>()
    var headerOrder: [(name: String, parent: Category)] = []
    for category in categories where !category.isSystem {
        if let parent = category.parent, !seen.contains(parent.name) {
            seen.insert(parent.name)
            headerOrder.append((parent.name, parent))
        }
    }
    // Sort headers by their sortOrder
    headerOrder.sort { $0.parent.sortOrder < $1.parent.sortOrder }

    var result: [CategoryGroup] = []
    for header in headerOrder {
        let subs = categories
            .filter { !$0.isSystem && $0.parent?.name == header.name }
            .sorted { $0.sortOrder < $1.sortOrder }
        if !subs.isEmpty {
            result.append(CategoryGroup(
                headerName: "\(header.parent.emoji) \(header.name)",
                subcategories: subs
            ))
        }
    }

    // Add any orphan (no parent, non-system) subcategories
    let orphans = categories
        .filter { !$0.isSystem && $0.parent == nil && !$0.isHeader }
        .sorted { $0.sortOrder < $1.sortOrder }
    if !orphans.isEmpty {
        result.append(CategoryGroup(headerName: "Other", subcategories: orphans))
    }

    return result
}

/// Returns the "To Budget" system category from a list of categories, if it exists.
func findToBudgetCategory(in categories: [Category]) -> Category? {
    categories.first { $0.isSystem && $0.name == DefaultCategories.toBudgetName }
}
