import WidgetKit
import SwiftUI

/// Widget definition for the Accounts widget.
/// Supports medium Home Screen and rectangular Lock Screen.
struct AccountsWidget: Widget {
    let kind = "AccountsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FamFinTimelineProvider()) { entry in
            AccountsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Account Balances")
        .description("View your account balances at a glance.")
        .supportedFamilies([
            .systemMedium,
            .accessoryRectangular,
        ])
    }
}

/// Routes to the correct view based on widget family.
struct AccountsWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: FamFinWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumAccountsView(entry: entry)
        case .accessoryRectangular:
            RectangularAccountView(entry: entry)
        default:
            MediumAccountsView(entry: entry)
        }
    }
}

#Preview("Medium", as: .systemMedium) {
    AccountsWidget()
} timeline: {
    FamFinWidgetEntry(date: .now, data: .placeholder)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    AccountsWidget()
} timeline: {
    FamFinWidgetEntry(date: .now, data: .placeholder)
}
