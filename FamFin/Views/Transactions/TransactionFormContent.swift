import SwiftUI
import SwiftData

/// The scrollable form body for the Add/Edit Transaction screen.
///
/// Contains the transaction type picker, and tappable rows for payee, account,
/// category, date, and memo. Each tappable row opens its respective search sheet.
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
    @State private var showDatePicker = false

    private var budgetAccounts: [Account] {
        accounts.filter { $0.isBudget }
    }

    private var trackingAccounts: [Account] {
        accounts.filter { !$0.isBudget }
    }

    private var groupedCategories: [CategoryGroup] {
        buildCategoryGroups(from: categories)
    }

    private var toBudgetCategory: Category? {
        findToBudgetCategory(in: categories)
    }

    var body: some View {
        Form {
            typeSection
            detailsSection
            accountSection
            categorySection
            deleteSection
        }
        .sheet(isPresented: $showingPayeeSearch) {
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
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        Section("Details") {
            // Payee row
            Button {
                showingPayeeSearch = true
            } label: {
                PickerRow(
                    label: "Payee",
                    value: viewModel.payee.isEmpty ? nil : viewModel.payee,
                    placeholder: viewModel.type == .transfer ? "Optional" : "Required",
                    systemImage: "person"
                )
            }
            .tint(.primary)

            // Memo
            TextField("Memo (optional)", text: Bindable(viewModel).memo)

            // Date row
            Button {
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
                DatePicker("", selection: Bindable(viewModel).date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .onChange(of: viewModel.date) { _, _ in
                        withAnimation(reduceMotion ? nil : .default) { showDatePicker = false }
                    }
            }
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        if viewModel.type == .transfer {
            transferAccountSections
        } else {
            singleAccountSection
        }
    }

    private var singleAccountSection: some View {
        Section("Account") {
            if accounts.isEmpty {
                Text("Add an account first")
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    showingAccountPicker = true
                } label: {
                    PickerRow(
                        label: "Account",
                        value: viewModel.selectedAccount?.name,
                        placeholder: "Select account",
                        systemImage: "building.columns"
                    )
                }
                .tint(.primary)

                if viewModel.selectedAccount == nil {
                    Text("An account is required.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    @ViewBuilder
    private var transferAccountSections: some View {
        Section("Transfer From") {
            if accounts.isEmpty {
                Text("Add an account first")
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    showingAccountPicker = true
                } label: {
                    PickerRow(
                        label: "From",
                        value: viewModel.selectedAccount?.name,
                        placeholder: "Select account",
                        systemImage: "arrow.up.right"
                    )
                }
                .tint(.primary)
            }
        }

        Section("Transfer To") {
            Button {
                showingTransferToPicker = true
            } label: {
                PickerRow(
                    label: "To",
                    value: viewModel.selectedTransferTo?.name,
                    placeholder: "Select account",
                    systemImage: "arrow.down.left"
                )
            }
            .tint(.primary)

            if let from = viewModel.selectedAccount, let to = viewModel.selectedTransferTo,
               from.persistentModelID == to.persistentModelID {
                Text("From and To accounts must be different.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if viewModel.transferNeedsCategory {
                Text("This transfer crosses Budget/Tracking boundary and needs a category.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private var categorySection: some View {
        if viewModel.showCategory {
            Section("Category") {
                if categories.isEmpty {
                    Text("No categories yet")
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        showingCategoryPicker = true
                    } label: {
                        PickerRow(
                            label: "Category",
                            value: viewModel.selectedCategory.map { "\($0.emoji) \($0.name)" },
                            placeholder: "Select category",
                            systemImage: "folder",
                            emoji: viewModel.selectedCategory?.emoji
                        )
                    }
                    .tint(.primary)

                    if viewModel.selectedCategory == nil {
                        Text("A category is required.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

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
