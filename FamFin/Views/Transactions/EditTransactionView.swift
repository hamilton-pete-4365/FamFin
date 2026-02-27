import SwiftUI
import SwiftData

/// Sheet for editing an existing transaction.
///
/// Opens with the form fields visible and keypad closed. The amount header is
/// tappable to re-open the keypad for amount changes. Includes a delete button.
struct EditTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    let transaction: Transaction

    @State private var viewModel = TransactionFormViewModel()
    @State private var hasLoaded = false
    @State private var showingDeleteConfirmation = false

    /// Only visible subcategories; includes currently assigned hidden category if applicable.
    private var categories: [Category] {
        var visible = allCategories.filter { !$0.isHeader && !$0.isHidden }
        if let current = transaction.category, current.isHidden,
           !visible.contains(where: { $0.persistentModelID == current.persistentModelID }) {
            visible.append(current)
        }
        return visible
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
                    categories: categories,
                    showDeleteButton: true,
                    onDelete: {
                        showingDeleteConfirmation = true
                    }
                )
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if viewModel.isKeypadVisible {
                    AmountKeypad(
                        engine: viewModel.engine,
                        onCancel: {
                            viewModel.handleKeypadCancel()
                        },
                        onDone: { amount in
                            viewModel.handleKeypadDone(amount: amount, currencyCode: currencyCode)
                        }
                    )
                    .padding(.top, 8)
                    .background(.bar)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: viewModel.isKeypadVisible)
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.update(transaction: transaction, context: modelContext, currencyCode: currencyCode)
                        HapticManager.success()
                        dismiss()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .onAppear {
                guard !hasLoaded else { return }
                hasLoaded = true
                viewModel.loadFromTransaction(transaction, currencyCode: currencyCode)
            }
            .confirmationDialog(
                "Delete Transaction?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(transaction)
                    dismiss()
                }
            } message: {
                Text("This will update your account balance and budget. This cannot be undone.")
            }
        }
    }
}
