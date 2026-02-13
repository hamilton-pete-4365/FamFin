import SwiftUI

struct ReportsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)

                Text("Reports")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Spending reports and insights will appear here.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Reports")
        }
    }
}

#Preview {
    ReportsView()
}
