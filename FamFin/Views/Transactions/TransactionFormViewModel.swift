import SwiftUI
import SwiftData

/// Shared view model for the Add and Edit Transaction screens.
///
/// Encapsulates all form state, validation logic, keypad integration, and persistence.
/// Both `AddTransactionView` and `EditTransactionView` create an instance of this class.
@Observable @MainActor
final class TransactionFormViewModel {

    // MARK: - Form State

    var amountPence: Int = 0
    var payee: String = ""
    var memo: String = ""
    var date: Date = Date()
    var type: TransactionType = .expense
    var selectedAccount: Account?
    var selectedTransferTo: Account?
    var selectedCategory: Category?
    var isKeypadVisible: Bool = true

    // MARK: - Engine

    let engine = AmountKeypadEngine()

    // MARK: - Computed — Validation

    /// Whether this transaction should have a category assigned.
    var shouldHaveCategory: Bool {
        if type == .transfer {
            guard let from = selectedAccount, let to = selectedTransferTo else { return false }
            return from.isBudget != to.isBudget
        }
        return selectedAccount?.isBudget ?? false
    }

    /// Whether the selected account is a Budget account.
    var selectedAccountIsBudget: Bool {
        selectedAccount?.isBudget ?? false
    }

    /// Whether the category picker should be shown.
    var showCategory: Bool {
        if type == .transfer {
            return shouldHaveCategory
        }
        return selectedAccountIsBudget
    }

    /// Whether this transfer crosses the Budget/Tracking boundary.
    var transferNeedsCategory: Bool {
        guard type == .transfer,
              let from = selectedAccount,
              let to = selectedTransferTo else { return false }
        return from.isBudget != to.isBudget
    }

    /// Whether all required fields are filled and the form can be saved.
    var canSave: Bool {
        guard amountPence > 0 else { return false }
        guard selectedAccount != nil else { return false }

        if type == .transfer {
            guard let to = selectedTransferTo,
                  selectedAccount?.persistentModelID != to.persistentModelID else { return false }
            if shouldHaveCategory && selectedCategory == nil { return false }
            return true
        }

        guard !payee.isEmpty else { return false }
        if shouldHaveCategory && selectedCategory == nil { return false }
        return true
    }

    // MARK: - Computed — Display

    /// Colour for the amount display based on transaction type.
    var amountColor: Color {
        guard amountPence > 0 else { return .secondary }
        switch type {
        case .expense: return .red
        case .income: return .green
        case .transfer: return .primary
        }
    }

    /// The sign prefix for the amount display.
    var amountSignPrefix: String {
        guard amountPence > 0 else { return "" }
        switch type {
        case .expense: return "-"
        case .income: return "+"
        case .transfer: return ""
        }
    }

    /// Convert amountPence to a Decimal in major units.
    func decimalAmount(currencyCode: String) -> Decimal {
        let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
        return Decimal(amountPence) / Decimal(currency.minorUnitMultiplier)
    }

    // MARK: - Keypad Lifecycle

    /// Activate the keypad for editing the amount.
    func activateKeypad(currencyCode: String) {
        engine.activate(currentPence: amountPence, currencyCode: currencyCode)
        isKeypadVisible = true
    }

    /// Handle the Done key from the keypad.
    func handleKeypadDone(amount: Decimal, currencyCode: String) {
        let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
        let multiplier = Decimal(currency.minorUnitMultiplier)
        amountPence = NSDecimalNumber(decimal: amount * multiplier).intValue
        isKeypadVisible = false
    }

    /// Handle the Cancel key from the keypad.
    /// Returns `true` if the keypad was dismissed (Edit mode), `false` if the sheet should dismiss (Add mode).
    @discardableResult
    func handleKeypadCancel() -> Bool {
        _ = engine.cancelTapped()
        isKeypadVisible = false
        // The caller decides whether to dismiss the sheet
        return true
    }

    // MARK: - Payee Auto-Fill

    /// Select a payee from the search sheet. Silently auto-fills category from the payee's history.
    func selectPayee(_ payeeRecord: Payee) {
        payee = payeeRecord.name
        if let lastCategory = payeeRecord.lastUsedCategory {
            selectedCategory = lastCategory
        }
    }

    // MARK: - Account Changes

    /// Call when the selected account changes. Clears category for Tracking accounts.
    func accountDidChange() {
        if let account = selectedAccount, !account.isBudget, type != .transfer {
            selectedCategory = nil
        }
    }

    // MARK: - Load from Existing Transaction (Edit)

    /// Populate form state from an existing transaction for editing.
    func loadFromTransaction(_ transaction: Transaction, currencyCode: String) {
        let currency = SupportedCurrency(rawValue: currencyCode) ?? .gbp
        let multiplier = Decimal(currency.minorUnitMultiplier)
        amountPence = NSDecimalNumber(decimal: transaction.amount * multiplier).intValue

        payee = transaction.payee
        memo = transaction.memo
        date = transaction.date
        type = transaction.type
        selectedAccount = transaction.account
        selectedTransferTo = transaction.transferToAccount
        selectedCategory = transaction.category
        isKeypadVisible = false
    }

    // MARK: - Persistence

    /// Save a new transaction to the model context.
    func save(context: ModelContext, currencyCode: String) {
        let amount = decimalAmount(currencyCode: currencyCode)
        let finalPayee = type == .transfer && payee.isEmpty ? "Transfer" : payee

        let transaction = Transaction(
            amount: amount,
            payee: finalPayee,
            memo: memo,
            date: date,
            type: type
        )

        transaction.account = selectedAccount
        if type == .transfer {
            transaction.transferToAccount = selectedTransferTo
        }
        transaction.category = shouldHaveCategory ? selectedCategory : nil

        context.insert(transaction)
        updatePayeeRecord(name: finalPayee, category: transaction.category, context: context)
    }

    /// Update an existing transaction in the model context.
    func update(transaction: Transaction, context: ModelContext, currencyCode: String) {
        let amount = decimalAmount(currencyCode: currencyCode)
        let finalPayee = type == .transfer && payee.isEmpty ? "Transfer" : payee

        transaction.amount = amount
        transaction.payee = finalPayee
        transaction.memo = memo
        transaction.date = date
        transaction.type = type
        transaction.account = selectedAccount
        transaction.transferToAccount = type == .transfer ? selectedTransferTo : nil
        transaction.category = shouldHaveCategory ? selectedCategory : nil

        updatePayeeRecord(name: finalPayee, category: transaction.category, context: context)
    }

    // MARK: - Private

    private func updatePayeeRecord(name: String, category: Category?, context: ModelContext) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "Transfer" else { return }

        let descriptor = FetchDescriptor<Payee>(predicate: #Predicate { $0.name == trimmed })
        if let existing = try? context.fetch(descriptor).first {
            existing.recordUsage(category: category)
        } else {
            let newPayee = Payee(name: trimmed, lastUsedCategory: category)
            context.insert(newPayee)
        }
    }
}
