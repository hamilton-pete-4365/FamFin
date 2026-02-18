import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab = 0
    @State private var navigateToAccountID: PersistentIdentifier?
    @State private var showingNewTransaction = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Budget", systemImage: "chart.pie.fill", value: 0) {
                BudgetView()
            }

            Tab("Accounts", systemImage: "banknote.fill", value: 1) {
                AccountsView(onSelectAccount: { accountID in
                    navigateToAccountID = accountID
                    selectedTab = 2
                })
            }

            Tab("Transactions", systemImage: "list.bullet.rectangle.fill", value: 2) {
                TransactionsTab(navigateToAccountID: $navigateToAccountID)
            }

            Tab("Goals", systemImage: "target", value: 3) {
                GoalsView()
            }

            Tab("Reports", systemImage: "chart.bar.fill", value: 4) {
                ReportsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
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
        case "goals":
            selectedTab = 3
        case "reports":
            selectedTab = 4
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
            Button("") { selectedTab = 3 }
                .keyboardShortcut("4", modifiers: .command)
            Button("") { selectedTab = 4 }
                .keyboardShortcut("5", modifiers: .command)
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
            SavingsGoal.self,
            RecurringTransaction.self,
            ActivityEntry.self
        ], inMemory: true)
        .environment(SharingManager())
        .environment(ReviewPromptManager())
}
