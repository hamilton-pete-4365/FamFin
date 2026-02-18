import WidgetKit
import SwiftUI

/// Widget definition for the "To Budget" widget.
/// Supports small Home Screen, circular Lock Screen, and inline Lock Screen.
struct ToBudgetWidget: Widget {
    let kind = "ToBudgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FamFinTimelineProvider()) { entry in
            ToBudgetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("To Budget")
        .description("See how much you have left to budget this month.")
        .supportedFamilies([
            .systemSmall,
            .accessoryCircular,
            .accessoryInline,
        ])
    }
}

/// Routes to the correct view based on widget family.
struct ToBudgetWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: FamFinWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallToBudgetView(entry: entry)
        case .accessoryCircular:
            CircularToBudgetView(entry: entry)
        case .accessoryInline:
            InlineToBudgetView(entry: entry)
        default:
            SmallToBudgetView(entry: entry)
        }
    }
}

#Preview("Small", as: .systemSmall) {
    ToBudgetWidget()
} timeline: {
    FamFinWidgetEntry(date: .now, data: .placeholder)
}

#Preview("Circular", as: .accessoryCircular) {
    ToBudgetWidget()
} timeline: {
    FamFinWidgetEntry(date: .now, data: .placeholder)
}

#Preview("Inline", as: .accessoryInline) {
    ToBudgetWidget()
} timeline: {
    FamFinWidgetEntry(date: .now, data: .placeholder)
}
