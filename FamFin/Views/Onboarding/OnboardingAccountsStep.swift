import SwiftUI
import SwiftData

/// Third onboarding step: create initial accounts with starting balances.
struct OnboardingAccountsStep: View {
    @Environment(\.modelContext) private var modelContext
    var onContinue: () -> Void
    var onSkip: () -> Void

    @State private var draftAccounts: [DraftAccount] = [
        DraftAccount(name: "Current Account", emoji: "🏦", isBudget: true),
        DraftAccount(name: "Savings", emoji: "🐷", isBudget: false),
    ]
    @State private var showingAddForm = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingAccountsHeader()

            OnboardingAccountsList(
                draftAccounts: $draftAccounts,
                showingAddForm: $showingAddForm
            )

            Spacer()

            OnboardingStepButtons(
                continueLabel: "Continue",
                onContinue: {
                    saveAccounts()
                    onContinue()
                },
                onSkip: onSkip
            )
        }
        .padding()
        .sheet(isPresented: $showingAddForm) {
            OnboardingAddAccountForm { draft in
                draftAccounts.append(draft)
            }
        }
    }

    private func saveAccounts() {
        for (index, draft) in draftAccounts.enumerated() {
            guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let account = Account(
                name: draft.name,
                type: draft.isBudget ? .current : .savings,
                isBudget: draft.isBudget,
                sortOrder: index
            )
            modelContext.insert(account)

            // If the user entered a starting balance, create an opening balance transaction
            if draft.balance != 0 {
                let transaction = Transaction(
                    amount: draft.balance < 0 ? -draft.balance : draft.balance,
                    payee: "Opening Balance",
                    memo: "",
                    date: Date(),
                    type: draft.balance >= 0 ? .income : .expense
                )
                transaction.account = account
                modelContext.insert(transaction)
            }
        }
        try? modelContext.save()
    }
}

/// A temporary draft account used during onboarding before persisting to SwiftData.
struct DraftAccount: Identifiable {
    let id = UUID()
    var name: String
    var emoji: String
    var balance: Decimal = 0
    var isBudget: Bool = true
}

// MARK: - Header

struct OnboardingAccountsHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "banknote.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("Set Up Accounts")
                .font(.title2.bold())

            Text("Add your bank accounts with starting balances. You can add more later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 16)
    }
}

// MARK: - List

struct OnboardingAccountsList: View {
    @Binding var draftAccounts: [DraftAccount]
    @Binding var showingAddForm: Bool
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"

    var body: some View {
        VStack(spacing: 0) {
            ForEach(draftAccounts) { draft in
                OnboardingAccountRow(
                    draft: binding(for: draft.id),
                    currencyCode: currencyCode,
                    onDelete: {
                        draftAccounts.removeAll { $0.id == draft.id }
                    }
                )
                if draft.id != draftAccounts.last?.id {
                    Divider().padding(.leading, 48)
                }
            }

            Button("Add Account", systemImage: "plus.circle") {
                showingAddForm = true
            }
            .padding(.top, 12)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func binding(for id: UUID) -> Binding<DraftAccount> {
        Binding(
            get: { draftAccounts[draftAccounts.firstIndex { $0.id == id }!] },
            set: { newValue in
                if let index = draftAccounts.firstIndex(where: { $0.id == id }) {
                    draftAccounts[index] = newValue
                }
            }
        )
    }
}

// MARK: - Row

struct OnboardingAccountRow: View {
    @Binding var draft: DraftAccount
    let currencyCode: String
    var onDelete: () -> Void

    @State private var balanceText = ""

    var body: some View {
        HStack(spacing: 12) {
            Text(draft.emoji)
                .font(.title2)
                .frame(width: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(draft.name)
                    .font(.headline)
                Text(draft.isBudget ? "Budget account" : "Tracking account")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            TextField("Balance", text: $balanceText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .onChange(of: balanceText) { _, newValue in
                    draft.balance = Decimal(string: newValue) ?? 0
                }

            Button("Remove", systemImage: "xmark.circle.fill") {
                onDelete()
            }
            .labelStyle(.iconOnly)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .onAppear {
            if draft.balance != 0 {
                balanceText = "\(draft.balance)"
            }
        }
    }
}

// MARK: - Add Account Form

struct OnboardingAddAccountForm: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: (DraftAccount) -> Void

    @State private var name = ""
    @State private var emoji = "🏦"
    @State private var isBudget = true

    private let emojiOptions = ["🏦", "💰", "🐷", "💳", "🏠", "📈", "💵", "🎯"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Account Name", text: $name)

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(emojiOptions, id: \.self) { option in
                            Button {
                                emoji = option
                            } label: {
                                Text(option)
                                    .font(.title)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        emoji == option
                                            ? Color.accentColor.opacity(0.2)
                                            : Color(.tertiarySystemGroupedBackground)
                                    )
                                    .clipShape(.rect(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    Toggle("Budget Account", isOn: $isBudget)
                } footer: {
                    Text("Budget accounts are part of your envelope budget. Tracking accounts (like investments) are monitored but not budgeted.")
                }
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let draft = DraftAccount(
                            name: name,
                            emoji: emoji,
                            isBudget: isBudget
                        )
                        onAdd(draft)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    OnboardingAccountsStep(onContinue: {}, onSkip: {})
        .modelContainer(for: Account.self, inMemory: true)
}
