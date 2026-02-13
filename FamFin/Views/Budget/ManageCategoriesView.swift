import SwiftUI
import SwiftData

// MARK: - Subcategory Row

/// A single subcategory row within a header section.
struct SubcategoryRow: View {
    let subcategory: Category
    let isEditing: Bool
    let onRename: () -> Void

    var body: some View {
        HStack {
            if isEditing {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
            }
            Text(subcategory.emoji)
            Text(subcategory.name)
                .font(.body)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing {
                onRename()
            }
        }
    }
}

// MARK: - Category Section Header

/// The header row for a category section, with optional edit/delete buttons.
struct CategorySectionHeader: View {
    let header: Category
    let isEditing: Bool
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text("\(header.emoji) \(header.name)")
                .font(.subheadline.bold())
                .textCase(nil)
            Spacer()
            if isEditing {
                Button {
                    onRename()
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Delete Alert Message

/// The confirmation message shown when deleting a header category.
struct DeleteAlertMessage: View {
    let category: Category?

    var body: some View {
        if let category {
            let childCount = category.children.count
            let transactionCount = category.children.reduce(0) { $0 + $1.transactions.count }
            if transactionCount > 0 {
                Text("This will delete \"\(category.name)\" and its \(childCount) subcategories. \(transactionCount) transactions will become uncategorised.")
            } else {
                Text("This will delete \"\(category.name)\" and its \(childCount) subcategories.")
            }
        } else {
            Text("Are you sure?")
        }
    }
}

// MARK: - Category Header Section

/// A full section for one header category: its subcategory rows, add button, and header row.
struct CategoryHeaderSection: View {
    @Environment(\.modelContext) private var modelContext
    let header: Category
    let isEditing: Bool
    @Binding var renamingCategory: Category?
    @Binding var addingSubcategoryTo: Category?
    @Binding var deletingCategory: Category?
    @Binding var showDeleteAlert: Bool

    var body: some View {
        Section {
            subcategoryList
            addButton
        } header: {
            CategorySectionHeader(
                header: header,
                isEditing: isEditing,
                onRename: { renamingCategory = header },
                onDelete: {
                    deletingCategory = header
                    showDeleteAlert = true
                }
            )
        }
    }

    private var subcategoryList: some View {
        ForEach(header.sortedChildren) { subcategory in
            SubcategoryRow(
                subcategory: subcategory,
                isEditing: isEditing,
                onRename: { renamingCategory = subcategory }
            )
        }
        .onDelete { offsets in
            let children = header.sortedChildren
            for index in offsets {
                modelContext.delete(children[index])
            }
            for (i, child) in header.sortedChildren.enumerated() {
                child.sortOrder = i
            }
        }
        .onMove { from, to in
            var children = header.sortedChildren
            children.move(fromOffsets: from, toOffset: to)
            for (i, child) in children.enumerated() {
                child.sortOrder = i
            }
        }
    }

    @ViewBuilder
    private var addButton: some View {
        if isEditing {
            Button {
                addingSubcategoryTo = header
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                    Text("Add Subcategory")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }
}

// MARK: - Manage Categories View

/// Dedicated screen for managing budget category headers and subcategories.
/// Accessible from the gear icon on the Budget tab.
struct ManageCategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]

    @State private var isEditing = false
    @State private var showingAddHeader = false
    @State private var addingSubcategoryTo: Category?
    @State private var renamingCategory: Category?
    @State private var deletingCategory: Category?
    @State private var showDeleteAlert = false

    var headerCategories: [Category] {
        allCategories
            .filter { $0.isHeader && !$0.isSystem }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        categoryList
            .navigationTitle("Manage Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingAddHeader) {
                AddHeaderView(nextSortOrder: headerCategories.count)
            }
            .sheet(item: $addingSubcategoryTo) { header in
                AddSubcategoryView(header: header, nextSortOrder: header.children.count)
            }
            .sheet(item: $renamingCategory) { category in
                RenameCategoryView(category: category)
            }
            .alert("Delete Category", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { deletingCategory = nil }
                Button("Delete", role: .destructive) {
                    if let category = deletingCategory {
                        deleteHeader(category)
                        deletingCategory = nil
                    }
                }
            } message: {
                DeleteAlertMessage(category: deletingCategory)
            }
    }

    private var categoryList: some View {
        List {
            ForEach(headerCategories) { header in
                CategoryHeaderSection(
                    header: header,
                    isEditing: isEditing,
                    renamingCategory: $renamingCategory,
                    addingSubcategoryTo: $addingSubcategoryTo,
                    deletingCategory: $deletingCategory,
                    showDeleteAlert: $showDeleteAlert
                )
            }
            .onMove { from, to in
                moveHeaders(from: from, to: to)
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if !headerCategories.isEmpty {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Add", systemImage: "plus") {
                showingAddHeader = true
            }
        }
    }

    // MARK: - Actions

    private func moveHeaders(from source: IndexSet, to destination: Int) {
        var headers = headerCategories
        headers.move(fromOffsets: source, toOffset: destination)
        for (i, header) in headers.enumerated() {
            header.sortOrder = i
        }
    }

    private func deleteHeader(_ header: Category) {
        modelContext.delete(header)
        let remaining = headerCategories.filter { $0.persistentModelID != header.persistentModelID }
        for (i, h) in remaining.enumerated() {
            h.sortOrder = i
        }
    }
}

// MARK: - Add Header View

struct AddHeaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let nextSortOrder: Int

    @State private var name = ""
    @State private var emoji = "📁"

    var body: some View {
        NavigationStack {
            Form {
                Section("Header Name") {
                    TextField("e.g. Household", text: $name)
                }
                Section("Emoji") {
                    TextField("Emoji", text: $emoji)
                        .font(.title)
                }
            }
            .navigationTitle("New Header")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let header = Category(
                            name: name.trimmingCharacters(in: .whitespaces),
                            emoji: emoji.trimmingCharacters(in: .whitespaces),
                            isHeader: true,
                            sortOrder: nextSortOrder
                        )
                        modelContext.insert(header)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Subcategory View

struct AddSubcategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let header: Category
    let nextSortOrder: Int

    @State private var name = ""
    @State private var emoji = "📁"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Under:")
                            .foregroundStyle(.secondary)
                        Text("\(header.emoji) \(header.name)")
                            .font(.headline)
                    }
                }
                Section("Category Name") {
                    TextField("e.g. Groceries", text: $name)
                }
                Section("Emoji") {
                    TextField("Emoji", text: $emoji)
                        .font(.title)
                }
            }
            .navigationTitle("New Subcategory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let sub = Category(
                            name: name.trimmingCharacters(in: .whitespaces),
                            emoji: emoji.trimmingCharacters(in: .whitespaces),
                            isHeader: false,
                            sortOrder: nextSortOrder
                        )
                        sub.parent = header
                        modelContext.insert(sub)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Rename Category View

struct RenameCategoryView: View {
    @Environment(\.dismiss) private var dismiss

    let category: Category

    @State private var name = ""
    @State private var emoji = ""
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category name", text: $name)
                }
                Section("Emoji") {
                    TextField("Emoji", text: $emoji)
                        .font(.title)
                }
            }
            .navigationTitle(category.isHeader ? "Rename Header" : "Rename Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        category.name = name.trimmingCharacters(in: .whitespaces)
                        category.emoji = emoji.trimmingCharacters(in: .whitespaces)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard !hasLoaded else { return }
                hasLoaded = true
                name = category.name
                emoji = category.emoji
            }
        }
    }
}
