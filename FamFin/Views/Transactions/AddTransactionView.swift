import SwiftUI
import SwiftData

/// Sheet for creating a new transaction.
///
/// Opens with the custom keypad active so the user can immediately enter an amount.
/// After tapping "Done" on the keypad, the form fields appear for payee, account,
/// category, date, and memo. The last-used account is remembered via `@AppStorage`.
struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"
    @AppStorage("lastUsedAccountID") private var lastUsedAccountID: String = ""

    var preselectedAccount: Account?
    var preselectedCategory: Category?

    @State private var viewModel = TransactionFormViewModel()
    @State private var hasInitialised = false

    /// Only visible subcategories (not headers, not hidden) are shown in the category picker.
    private var categories: [Category] {
        allCategories.filter { !$0.isHeader && !$0.isHidden }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TransactionAmountHeader(
                    viewModel: viewModel,
                    currencyCode: currencyCode,
                    onTapToEdit: {
                        viewModel.activateKeypad(currencyCode: currencyCode)
                    }
                )

                TransactionFormContent(
                    viewModel: viewModel,
                    accounts: accounts,
                    categories: categories
                )
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if viewModel.isKeypadVisible {
                    AmountKeypad(
                        engine: viewModel.engine,
                        onCancel: {
                            viewModel.handleKeypadCancel()
                            dismiss()
                        },
                        onDone: { amount in
                            viewModel.handleKeypadDone(amount: amount, currencyCode: currencyCode)
                        }
                    )
                    .padding(.top, 8)
                    .background(.bar)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                } else if !viewModel.isDatePickerVisible {
                    HStack {
                        Spacer()

                        Button {
                            viewModel.save(context: modelContext, currencyCode: currencyCode)
                            if let account = viewModel.selectedAccount {
                                lastUsedAccountID = "\(account.persistentModelID)"
                            }
                            HapticManager.success()
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(.title3)
                                .bold()
                                .foregroundStyle(viewModel.canSave ? .white : .accent)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background {
                                    if viewModel.canSave {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.accent)
                                    } else {
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(.accent, lineWidth: 1.5)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.canSave)
                        .animation(reduceMotion ? nil : .default, value: viewModel.canSave)
                    }
                    .padding()
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: viewModel.isKeypadVisible)
            .animation(reduceMotion ? nil : .default, value: viewModel.isDatePickerVisible)
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                guard !hasInitialised else { return }
                hasInitialised = true

                // Activate keypad immediately
                viewModel.engine.activate(currentPence: 0, currencyCode: currencyCode)
                viewModel.isKeypadVisible = true

                // Set initial account: preselected > last used > first budget account > single account
                if let preselected = preselectedAccount {
                    viewModel.selectedAccount = preselected
                } else if !lastUsedAccountID.isEmpty,
                          let lastUsed = accounts.first(where: { "\($0.persistentModelID)" == lastUsedAccountID }) {
                    viewModel.selectedAccount = lastUsed
                } else if let firstBudget = accounts.first(where: { $0.isBudget }) {
                    viewModel.selectedAccount = firstBudget
                } else if accounts.count == 1 {
                    viewModel.selectedAccount = accounts.first
                }

                if let preselected = preselectedCategory {
                    viewModel.selectedCategory = preselected
                }
            }
        }
    }
}
