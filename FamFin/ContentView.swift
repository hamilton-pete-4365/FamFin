import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            BudgetView()
                .tabItem {
                    Label("Budget", systemImage: "chart.pie.fill")
                }

            AccountsView()
                .tabItem {
                    Label("Accounts", systemImage: "banknote.fill")
                }

            TransactionsTab()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet.rectangle.fill")
                }

            GoalsView()
                .tabItem {
                    Label("Goals", systemImage: "target")
                }

            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "chart.bar.fill")
                }
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
