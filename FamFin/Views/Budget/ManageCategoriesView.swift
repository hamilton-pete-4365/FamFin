import SwiftUI
import SwiftData

// MARK: - Manage Categories View

/// Dedicated screen for managing budget category headers and subcategories.
/// Supports inline add/rename, reorder, hide/unhide, move between groups, and delete.
struct ManageCategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]

    // MARK: - State

    @State private var isReordering = false

    /// The category currently being renamed inline (TextField shown instead of label)
    @State private var renamingCategoryID: PersistentIdentifier?
    @State private var renameText = ""

    /// The category whose emoji is being edited inline
    @State private var editingEmojiID: PersistentIdentifier?
    @State private var emojiText = ""

    /// The header we're adding a new subcategory to (shows inline TextField)
    @State private var addingToHeaderID: PersistentIdentifier?
    @State private var newCategoryName = ""

    /// Whether we're adding a new header group
    @State private var isAddingHeader = false
    @State private var newHeaderName = ""

    /// Category pending deletion (triggers confirmation dialog)
    @State private var deletingCategory: Category?

    /// Whether the hidden section is expanded
    @State private var hiddenExpanded = false

    // MARK: - Computed

    var headerCategories: [Category] {
        allCategories
            .filter { $0.isHeader && !$0.isSystem && !$0.isHidden }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var hiddenCategories: [Category] {
        allCategories.filter { $0.isHidden && !$0.isSystem }
    }

    // MARK: - Body

    var body: some View {
        List {
            ForEach(headerCategories) { header in
                categorySection(for: header)
            }
            .onMove { from, to in
                moveHeaders(from: from, to: to)
            }

            if isAddingHeader {
                addHeaderSection
            }

            if !hiddenCategories.isEmpty {
                hiddenSection
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(isReordering ? .active : .inactive))
        .navigationTitle("Manage Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .confirmationDialog(
            deletionTitle,
            isPresented: .init(
                get: { deletingCategory != nil },
                set: { if !$0 { deletingCategory = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let category = deletingCategory {
                    deleteCategory(category)
                }
            }
        } message: {
            Text(deletionMessage)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Add Group", systemImage: "folder.badge.plus") {
                    beginAddingHeader()
                }
                Button(
                    isReordering ? "Done Reordering" : "Edit Order",
                    systemImage: isReordering ? "checkmark" : "arrow.up.arrow.down"
                ) {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        isReordering.toggle()
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .accessibilityLabel("Options")
            }
        }
    }

    // MARK: - Category Section

    @ViewBuilder
    private func categorySection(for header: Category) -> some View {
        Section {
            ForEach(header.sortedChildren.filter { !$0.isHidden }) { subcategory in
                subcategoryRow(subcategory, in: header)
            }
            .onDelete { offsets in
                deleteSubcategories(at: offsets, in: header)
            }
            .onMove { from, to in
                moveSubcategories(from: from, to: to, in: header)
            }

            if addingToHeaderID == header.persistentModelID {
                inlineAddRow(for: header)
            }

            if !isReordering {
                addCategoryButton(for: header)
            }
        } header: {
            headerRow(for: header)
        }
    }

    // MARK: - Header Row

    private func headerRow(for header: Category) -> some View {
        HStack {
            if editingEmojiID == header.persistentModelID {
                inlineEmojiField { newEmoji in
                    header.emoji = newEmoji
                    editingEmojiID = nil
                    HapticManager.selection()
                }
            } else {
                Text(header.emoji)
                    .onTapGesture {
                        beginEditingEmoji(for: header)
                    }
            }

            if renamingCategoryID == header.persistentModelID {
                inlineRenameField { newName in
                    header.name = newName
                    renamingCategoryID = nil
                    try? modelContext.save()
                    HapticManager.medium()
                }
            } else {
                Text(header.name.uppercased())
                    .font(.subheadline.bold())
            }

            Spacer()

            Text("\(header.visibleSortedChildren.count)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .textCase(nil)
        .contextMenu {
            Button("Rename", systemImage: "pencil") {
                beginRenaming(header)
            }
            Button("Change Emoji", systemImage: "face.smiling") {
                beginEditingEmoji(for: header)
            }
            Divider()
            Button("Hide Group", systemImage: "eye.slash") {
                hideCategory(header)
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                deletingCategory = header
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("\(header.name) group, \(header.visibleSortedChildren.count) categories")
    }

    // MARK: - Subcategory Row

    private func subcategoryRow(_ subcategory: Category, in header: Category) -> some View {
        HStack(spacing: 8) {
            if editingEmojiID == subcategory.persistentModelID {
                inlineEmojiField { newEmoji in
                    subcategory.emoji = newEmoji
                    editingEmojiID = nil
                    HapticManager.selection()
                }
            } else {
                Text(subcategory.emoji)
                    .onTapGesture {
                        beginEditingEmoji(for: subcategory)
                    }
            }

            if renamingCategoryID == subcategory.persistentModelID {
                inlineRenameField { newName in
                    subcategory.name = newName
                    renamingCategoryID = nil
                    try? modelContext.save()
                    HapticManager.medium()
                }
            } else {
                Text(subcategory.name)
                    .font(.body)
            }

            Spacer()

            let count = subcategory.transactionCount
            Text(count == 0 ? "No transactions" : "\(count) transaction\(count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isReordering {
                beginRenaming(subcategory)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                deletingCategory = subcategory
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button("Hide", systemImage: "eye.slash") {
                hideCategory(subcategory)
            }
            .tint(.blue)
        }
        .contextMenu {
            Button("Rename", systemImage: "pencil") {
                beginRenaming(subcategory)
            }
            Button("Change Emoji", systemImage: "face.smiling") {
                beginEditingEmoji(for: subcategory)
            }
            moveMenu(for: subcategory, currentHeader: header)
            Divider()
            Button("Hide", systemImage: "eye.slash") {
                hideCategory(subcategory)
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                deletingCategory = subcategory
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subcategory.name), \(subcategory.transactionCount) transactions")
        .accessibilityHint("Tap to rename. Swipe for more actions.")
    }

    // MARK: - Move Menu

    @ViewBuilder
    private func moveMenu(for subcategory: Category, currentHeader: Category) -> some View {
        let otherHeaders = headerCategories.filter {
            $0.persistentModelID != currentHeader.persistentModelID
        }
        if !otherHeaders.isEmpty {
            Menu("Move to...", systemImage: "arrow.right") {
                ForEach(otherHeaders) { header in
                    Button("\(header.emoji) \(header.name)") {
                        moveCategory(subcategory, toHeader: header)
                    }
                }
            }
        }
    }

    // MARK: - Add Category Button

    private func addCategoryButton(for header: Category) -> some View {
        Button {
            beginAddingCategory(to: header)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.green)
                Text("Add Category")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .accessibilityLabel("Add category to \(header.name)")
    }

    // MARK: - Inline Add Row

    private func inlineAddRow(for header: Category) -> some View {
        HStack(spacing: 8) {
            Text(header.emoji)
            TextField("Category name", text: $newCategoryName)
                .onSubmit {
                    saveNewCategory(to: header)
                }
                .submitLabel(.done)
        }
        .onAppear {
            // Auto-focus is handled by SwiftUI's TextField focus
        }
    }

    // MARK: - Add Header Section

    private var addHeaderSection: some View {
        Section {
            HStack(spacing: 8) {
                Text("📁")
                TextField("Group name", text: $newHeaderName)
                    .font(.subheadline.bold())
                    .onSubmit {
                        saveNewHeader()
                    }
                    .submitLabel(.done)
            }
        }
    }

    // MARK: - Hidden Section

    private var hiddenSection: some View {
        Section {
            if hiddenExpanded {
                ForEach(hiddenCategories) { category in
                    hiddenRow(for: category)
                }
            }
        } header: {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    hiddenExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Hidden (\(hiddenCategories.count))")
                        .font(.subheadline.bold())
                        .textCase(nil)
                    Spacer()
                    Image(systemName: hiddenExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("Hidden categories, \(hiddenCategories.count)")
            .accessibilityHint(hiddenExpanded ? "Double tap to collapse" : "Double tap to expand")
        }
    }

    private func hiddenRow(for category: Category) -> some View {
        HStack(spacing: 8) {
            Text(category.emoji)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.body)
                if category.isHeader {
                    Text("\(category.children.count) subcategories")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    let count = category.transactionCount
                    Text(count == 0 ? "No transactions" : "\(count) transaction\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button("Unhide", systemImage: "eye") {
                unhideCategory(category)
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                deletingCategory = category
            }
        }
        .contextMenu {
            Button("Unhide", systemImage: "eye") {
                unhideCategory(category)
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                deletingCategory = category
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.name), hidden")
        .accessibilityHint("Swipe right to unhide")
    }

    // MARK: - Inline Fields

    /// A TextField for inline renaming. Calls `onSave` with the trimmed name on submit.
    private func inlineRenameField(onSave: @escaping (String) -> Void) -> some View {
        TextField("Name", text: $renameText)
            .onSubmit {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    onSave(trimmed)
                } else {
                    renamingCategoryID = nil
                }
            }
            .submitLabel(.done)
    }

    /// A single-character TextField for inline emoji editing.
    private func inlineEmojiField(onSave: @escaping (String) -> Void) -> some View {
        TextField("", text: $emojiText)
            .font(.title2)
            .frame(width: 36)
            .multilineTextAlignment(.center)
            .onChange(of: emojiText) { _, newValue in
                if newValue.count > 1 {
                    emojiText = String(newValue.suffix(1))
                }
            }
            .onSubmit {
                let trimmed = emojiText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    onSave(trimmed)
                } else {
                    editingEmojiID = nil
                }
            }
            .submitLabel(.done)
    }

    // MARK: - Actions

    private func beginRenaming(_ category: Category) {
        guard !isReordering else { return }
        editingEmojiID = nil
        addingToHeaderID = nil
        isAddingHeader = false
        renamingCategoryID = category.persistentModelID
        renameText = category.name
    }

    private func beginEditingEmoji(for category: Category) {
        guard !isReordering else { return }
        renamingCategoryID = nil
        addingToHeaderID = nil
        isAddingHeader = false
        editingEmojiID = category.persistentModelID
        emojiText = category.emoji
    }

    private func beginAddingCategory(to header: Category) {
        renamingCategoryID = nil
        editingEmojiID = nil
        isAddingHeader = false
        newCategoryName = ""
        addingToHeaderID = header.persistentModelID
    }

    private func beginAddingHeader() {
        renamingCategoryID = nil
        editingEmojiID = nil
        addingToHeaderID = nil
        newHeaderName = ""
        isAddingHeader = true
    }

    private func saveNewCategory(to header: Category) {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addingToHeaderID = nil
            return
        }
        let sub = Category(
            name: trimmed,
            emoji: header.emoji,
            isHeader: false,
            sortOrder: header.children.count
        )
        sub.parent = header
        modelContext.insert(sub)
        try? modelContext.save()
        HapticManager.medium()
        addingToHeaderID = nil
        newCategoryName = ""
    }

    private func saveNewHeader() {
        let trimmed = newHeaderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isAddingHeader = false
            return
        }
        let header = Category(
            name: trimmed,
            emoji: "📁",
            isHeader: true,
            sortOrder: headerCategories.count
        )
        modelContext.insert(header)
        try? modelContext.save()
        HapticManager.medium()
        isAddingHeader = false
        newHeaderName = ""
    }

    private func hideCategory(_ category: Category) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            category.isHidden = true
            if category.isHeader {
                for child in category.children {
                    child.isHidden = true
                }
            }
            try? modelContext.save()
        }
        HapticManager.light()
    }

    private func unhideCategory(_ category: Category) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            category.isHidden = false
            if category.isHeader {
                for child in category.children {
                    child.isHidden = false
                }
            }
            try? modelContext.save()
        }
        HapticManager.light()
    }

    private func moveCategory(_ subcategory: Category, toHeader newHeader: Category) {
        let oldParent = subcategory.parent

        subcategory.parent = newHeader
        subcategory.sortOrder = newHeader.children.count

        // Reindex the old parent's remaining children
        if let oldParent {
            let remaining = oldParent.sortedChildren.filter {
                $0.persistentModelID != subcategory.persistentModelID
            }
            for (i, child) in remaining.enumerated() {
                child.sortOrder = i
            }
        }

        try? modelContext.save()
        HapticManager.medium()
    }

    private func moveHeaders(from source: IndexSet, to destination: Int) {
        var headers = headerCategories
        headers.move(fromOffsets: source, toOffset: destination)
        for (i, header) in headers.enumerated() {
            header.sortOrder = i
        }
        try? modelContext.save()
    }

    private func moveSubcategories(from source: IndexSet, to destination: Int, in header: Category) {
        var children = header.sortedChildren.filter { !$0.isHidden }
        children.move(fromOffsets: source, toOffset: destination)
        for (i, child) in children.enumerated() {
            child.sortOrder = i
        }
        try? modelContext.save()
    }

    private func deleteSubcategories(at offsets: IndexSet, in header: Category) {
        let visibleChildren = header.sortedChildren.filter { !$0.isHidden }
        let deletedIDs = Set(offsets.map { visibleChildren[$0].persistentModelID })
        for index in offsets {
            modelContext.delete(visibleChildren[index])
        }
        let remaining = header.sortedChildren.filter { !deletedIDs.contains($0.persistentModelID) }
        for (i, child) in remaining.enumerated() {
            child.sortOrder = i
        }
        try? modelContext.save()
        HapticManager.error()
    }

    private func deleteCategory(_ category: Category) {
        if category.isHeader {
            modelContext.delete(category)
            let remaining = headerCategories.filter { $0.persistentModelID != category.persistentModelID }
            for (i, h) in remaining.enumerated() {
                h.sortOrder = i
            }
        } else {
            let parent = category.parent
            modelContext.delete(category)
            if let parent {
                let remaining = parent.sortedChildren.filter {
                    $0.persistentModelID != category.persistentModelID
                }
                for (i, child) in remaining.enumerated() {
                    child.sortOrder = i
                }
            }
        }
        try? modelContext.save()
        deletingCategory = nil
        HapticManager.error()
    }

    // MARK: - Deletion Dialog Helpers

    private var deletionTitle: String {
        guard let category = deletingCategory else { return "Delete?" }
        return "Delete \(category.name)?"
    }

    private var deletionMessage: String {
        guard let category = deletingCategory else { return "" }
        if category.isHeader {
            let childCount = category.children.count
            let txCount = category.transactionCount
            if txCount > 0 {
                return "This will delete \(category.name) and its \(childCount) subcategories. \(txCount) transactions will become uncategorised."
            }
            return "This will delete \(category.name) and its \(childCount) subcategories."
        } else {
            let txCount = category.transactionCount
            if txCount > 0 {
                return "\(txCount) transaction\(txCount == 1 ? "" : "s") will become uncategorised."
            }
            return "This category has no transactions."
        }
    }
}
