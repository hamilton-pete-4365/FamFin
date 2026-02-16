import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var navigateToAccountID: PersistentIdentifier?

    var body: some View {
        TabView(selection: $selectedTab) {
            BudgetView()
                .tabItem {
                    Label("Budget", systemImage: "chart.pie.fill")
                }
                .tag(0)

            AccountsView(onSelectAccount: { accountID in
                navigateToAccountID = accountID
                selectedTab = 2
            })
            .tabItem {
                Label("Accounts", systemImage: "banknote.fill")
            }
            .tag(1)

            TransactionsTab(navigateToAccountID: $navigateToAccountID)
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet.rectangle.fill")
                }
                .tag(2)

            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "chart.bar.fill")
                }
                .tag(3)
        }
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
            SavingsGoal.self
        ], inMemory: true)
}
