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
                    .padding(.top, 20)
                    .background(.bar)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: viewModel.isKeypadVisible)
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save(context: modelContext, currencyCode: currencyCode)
                        if let account = viewModel.selectedAccount {
                            lastUsedAccountID = "\(account.persistentModelID)"
                        }
                        HapticManager.success()
                        dismiss()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .onAppear {
                guard !hasInitialised else { return }
                hasInitialised = true

                // Activate keypad immediately
                viewModel.engine.activate(currentPence: 0, currencyCode: currencyCode)
                viewModel.isKeypadVisible = true

                // Set initial account: preselected > last used > single account
                if let preselected = preselectedAccount {
                    viewModel.selectedAccount = preselected
                } else if !lastUsedAccountID.isEmpty {
                    viewModel.selectedAccount = accounts.first {
                        "\($0.persistentModelID)" == lastUsedAccountID
                    }
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
