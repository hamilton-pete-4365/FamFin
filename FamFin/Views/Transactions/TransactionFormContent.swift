import SwiftUI
import SwiftData

/// The scrollable form body for the Add/Edit Transaction screen.
///
/// Contains the transaction type picker, and tappable rows for payee, category,
/// account, date, and memo. The four key rows always remain in the same position.
struct TransactionFormContent: View {
    let viewModel: TransactionFormViewModel
    let accounts: [Account]
    let categories: [Category]
    var showDeleteButton: Bool = false
    var onDelete: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingPayeeSearch = false
    @State private var showingAccountPicker = false
    @State private var showingTransferToPicker = false
    @State private var showingCategoryPicker = false
    /// Bound to the view model so the parent view can observe date picker visibility.
    private var showDatePicker: Bool {
        get { viewModel.isDatePickerVisible }
        nonmutating set { viewModel.isDatePickerVisible = newValue }
    }
    @State private var accountBeforeTransfer: Account?
    @FocusState private var isMemoFocused: Bool

    private var groupedCategories: [CategoryGroup] {
        buildCategoryGroups(from: categories)
    }

    private var toBudgetCategory: Category? {
        findToBudgetCategory(in: categories)
    }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                typeSection
                detailsSection
                memoSection
                deleteSection
            }
            .onChange(of: showDatePicker) {
                if showDatePicker {
                    withAnimation(reduceMotion ? nil : .default) {
                        proxy.scrollTo("datePicker", anchor: .bottom)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showingPayeeSearch) {
            PayeeSearchSheet(
                onSelect: { payee in
                    viewModel.selectPayee(payee)
                },
                onCustomPayee: { name in
                    viewModel.payee = name
                }
            )
        }
        .sheet(isPresented: $showingAccountPicker) {
            AccountPickerSheet(accounts: accounts) { account in
                viewModel.selectedAccount = account
                viewModel.accountDidChange()
            }
        }
        .sheet(isPresented: $showingTransferToPicker) {
            AccountPickerSheet(
                accounts: accounts,
                excludeAccount: viewModel.selectedAccount
            ) { account in
                viewModel.selectedTransferTo = account
            }
        }
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryPickerSheet(
                categories: categories,
                groupedCategories: groupedCategories,
                toBudgetCategory: toBudgetCategory
            ) { category in
                viewModel.selectedCategory = category
            }
        }
    }

    // MARK: - Sections

    private var typeSection: some View {
        Section {
            Picker("Type", selection: Bindable(viewModel).type) {
                ForEach(TransactionType.allCases) { transType in
                    Text(transType.rawValue).tag(transType)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.type) { _, newType in
                if newType == .transfer {
                    accountBeforeTransfer = viewModel.selectedAccount
                    viewModel.selectedAccount = nil
                    viewModel.selectedTransferTo = nil
                    viewModel.selectedCategory = nil
                } else {
                    if viewModel.selectedAccount == nil, let saved = accountBeforeTransfer {
                        viewModel.selectedAccount = saved
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        Section {
            // Payee — hidden for transfers
            if viewModel.type != .transfer {
                payeeRow
            }

            // Category — always shown, disabled for tracking accounts
            categoryRow

            // Account(s) — single or transfer from/to
            if viewModel.type == .transfer {
                transferAccountRows
            } else {
                singleAccountRow
            }

            // Date — always shown
            dateRow
        }
    }

    // MARK: - Payee

    private var payeeRow: some View {
        Button {
            let keypadWasVisible = viewModel.isKeypadVisible
            viewModel.dismissKeypadIfVisible()
            if keypadWasVisible {
                Task { @MainActor in
                    showingPayeeSearch = true
                }
            } else {
                showingPayeeSearch = true
            }
        } label: {
            PickerRow(
                label: "Payee",
                value: viewModel.payee.isEmpty ? nil : viewModel.payee,
                placeholder: viewModel.type == .transfer ? "Optional" : "Required",
                systemImage: "person"
            )
        }
        .tint(.primary)
    }

    // MARK: - Category

    @ViewBuilder
    private var categoryRow: some View {
        if viewModel.isCategoryEnabled {
            Button {
                viewModel.dismissKeypadIfVisible()
                showingCategoryPicker = true
            } label: {
                PickerRow(
                    label: "Category",
                    value: viewModel.selectedCategory.map { "\($0.emoji) \($0.name)" },
                    placeholder: "Required",
                    systemImage: "folder"
                )
            }
            .tint(.primary)
        } else {
            PickerRow(
                label: "Category",
                value: nil,
                placeholder: "Not applicable",
                systemImage: "folder"
            )
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Account

    @ViewBuilder
    private var singleAccountRow: some View {
        Button {
            viewModel.dismissKeypadIfVisible()
            showingAccountPicker = true
        } label: {
            PickerRow(
                label: "Account",
                value: viewModel.selectedAccount?.name,
                placeholder: "Required",
                systemImage: "building.columns"
            )
        }
        .tint(.primary)
    }

    @ViewBuilder
    private var transferAccountRows: some View {
        Button {
            viewModel.dismissKeypadIfVisible()
            showingAccountPicker = true
        } label: {
            PickerRow(
                label: "From",
                value: viewModel.selectedAccount?.name,
                placeholder: "Required",
                systemImage: "arrow.up.right"
            )
        }
        .tint(.primary)

        Button {
            viewModel.dismissKeypadIfVisible()
            showingTransferToPicker = true
        } label: {
            PickerRow(
                label: "To",
                value: viewModel.selectedTransferTo?.name,
                placeholder: "Required",
                systemImage: "arrow.down.left"
            )
        }
        .tint(.primary)
    }

    // MARK: - Date

    @ViewBuilder
    private var dateRow: some View {
        Button {
            viewModel.dismissKeypadIfVisible()
            isMemoFocused = false
            withAnimation(reduceMotion ? nil : .default) { showDatePicker.toggle() }
        } label: {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Date")
                    .foregroundStyle(.primary)
                Spacer()
                Text(viewModel.date, format: .dateTime.day().month().year())
                    .foregroundStyle(showDatePicker ? Color.accentColor : .secondary)
            }
        }
        .tint(.primary)

        if showDatePicker {
            CalendarDatePicker(selectedDate: Bindable(viewModel).date) {
                withAnimation(reduceMotion ? nil : .default) { showDatePicker = false }
            }
            .id("datePicker")
        }
    }

    // MARK: - Memo

    private var memoSection: some View {
        Section {
            TextField("Memo (optional)", text: Bindable(viewModel).memo)
                .focused($isMemoFocused)
                .submitLabel(.done)
                .onChange(of: isMemoFocused) {
                    if isMemoFocused {
                        viewModel.dismissKeypadIfVisible()
                    }
                }
        }
    }

    // MARK: - Delete

    @ViewBuilder
    private var deleteSection: some View {
        if showDeleteButton, let onDelete {
            Section {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete Transaction")
                        Spacer()
                    }
                }
            }
        }
    }
}
