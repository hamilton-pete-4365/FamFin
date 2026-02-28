import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab = 0
    @State private var showingNewTransaction = false
    @State private var previousTab = 0
    @State private var monthStore = SelectedMonthStore()

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
        .environment(monthStore)
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
            AddTransactionView(defaultDate: defaultTransactionDate)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )) {
            OnboardingView()
        }
    }

    /// When the selected month is not the current month, default new transactions
    /// to the last day of that month; otherwise use today (nil = default).
    private var defaultTransactionDate: Date? {
        let calendar = Calendar.current
        guard !calendar.isDate(monthStore.selectedMonth, equalTo: Date(), toGranularity: .month) else {
            return nil
        }
        let month = monthStore.selectedMonth
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let lastDay = calendar.date(bySetting: .day, value: range.upperBound - 1, of: month)
        else { return month }
        return lastDay
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
            BudgetAllocation.self
        ], inMemory: true)
}
