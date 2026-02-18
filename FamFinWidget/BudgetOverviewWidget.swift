import WidgetKit
import SwiftUI

/// Widget definition for the Budget Overview widget.
/// Supports the large Home Screen family.
struct BudgetOverviewWidget: Widget {
    let kind = "BudgetOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FamFinTimelineProvider()) { entry in
            LargeBudgetOverviewView(entry: entry)
        }
        .configurationDisplayName("Budget Overview")
        .description("See your budget status and category balances.")
        .supportedFamilies([.systemLarge])
    }
}

#Preview("Large", as: .systemLarge) {
    BudgetOverviewWidget()
} timeline: {
    FamFinWidgetEntry(date: .now, data: .placeholder)
}
