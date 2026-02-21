import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab = 0
    @State private var showingNewTransaction = false
    @State private var previousTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Budget", systemImage: "chart.pie.fill", value: 0) {
                BudgetView()
            }

            Tab("Accounts", systemImage: "banknote.fill", value: 1) {
                AccountsView()
            }

            Tab("Transactions", systemImage: "list.bullet.rectangle.fill", value: 2) {
                TransactionsTab()
            }

        }
        .tabViewStyle(.sidebarAdaptable)
        .onChange(of: selectedTab) { oldValue, newValue in
            // Double-tap Transactions tab to open Add Transaction
            if oldValue == 2, newValue == 2 {
                showingNewTransaction = true
            }
            previousTab = oldValue
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .overlay {
            KeyboardShortcutButtons(
                selectedTab: $selectedTab,
                showingNewTransaction: $showingNewTransaction
            )
        }
        .sheet(isPresented: $showingNewTransaction) {
            AddTransactionView()
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )) {
            OnboardingView()
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "famfin" else { return }
        switch url.host {
        case "budget":
            selectedTab = 0
        case "accounts":
            selectedTab = 1
        case "transactions":
            selectedTab = 2
        default:
            break
        }
    }
}

/// Hidden buttons providing iPad keyboard shortcuts.
/// Invisible to the user but responds to Cmd+1–5 and Cmd+N.
struct KeyboardShortcutButtons: View {
    @Binding var selectedTab: Int
    @Binding var showingNewTransaction: Bool

    var body: some View {
        Group {
            Button("") { selectedTab = 0 }
                .keyboardShortcut("1", modifiers: .command)
            Button("") { selectedTab = 1 }
                .keyboardShortcut("2", modifiers: .command)
            Button("") { selectedTab = 2 }
                .keyboardShortcut("3", modifiers: .command)
            Button("") { showingNewTransaction = true }
                .keyboardShortcut("n", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Account.self,
            Transaction.self,
            Category.self,
            BudgetMonth.self,
            BudgetAllocation.self,
            RecurringTransaction.self,
            ActivityEntry.self
        ], inMemory: true)
        .environment(SharingManager())
        .environment(ReviewPromptManager())
}
