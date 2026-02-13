import SwiftUI
import SwiftData

struct GoalsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "target")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)

                Text("Goals")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Set savings goals and track your progress.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Goals")
        }
    }
}

#Preview {
    GoalsView()
        .modelContainer(for: SavingsGoal.self, inMemory: true)
}
