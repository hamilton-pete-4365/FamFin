import WidgetKit
import SwiftUI

/// Timeline entry that carries all data needed by every widget family.
struct FamFinWidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetDataProvider.WidgetData
}

/// Provides timeline entries for all FamFin widgets.
struct FamFinTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> FamFinWidgetEntry {
        FamFinWidgetEntry(date: .now, data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (FamFinWidgetEntry) -> Void) {
        if context.isPreview {
            completion(FamFinWidgetEntry(date: .now, data: .placeholder))
        } else {
            let data = WidgetDataProvider.loadData()
            completion(FamFinWidgetEntry(date: .now, data: data))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FamFinWidgetEntry>) -> Void) {
        let data = WidgetDataProvider.loadData()
        let entry = FamFinWidgetEntry(date: .now, data: data)

        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Placeholder Data

extension WidgetDataProvider.WidgetData {

    /// Sample data used for widget previews and placeholders.
    static let placeholder = WidgetDataProvider.WidgetData(
        toBudgetAmount: Decimal(string: "1250.00") ?? 1250,
        totalBudgeted: Decimal(string: "3500.00") ?? 3500,
        totalIncome: Decimal(string: "4750.00") ?? 4750,
        accounts: [
            .init(name: "Current", balance: Decimal(string: "2340.50") ?? 2340, type: "Current"),
            .init(name: "Savings", balance: Decimal(string: "15000.00") ?? 15000, type: "Savings"),
            .init(name: "Credit Card", balance: Decimal(string: "-450.25") ?? -450, type: "Credit Card"),
        ],
        overspentCategories: [
            .init(name: "Dining Out", emoji: "🍔", available: Decimal(string: "-45.00") ?? -45),
            .init(name: "Entertainment", emoji: "🎬", available: Decimal(string: "-22.50") ?? -22),
        ],
        topCategories: [
            .init(name: "Groceries", emoji: "🛒", available: Decimal(string: "180.00") ?? 180),
            .init(name: "Transport", emoji: "🚗", available: Decimal(string: "95.00") ?? 95),
            .init(name: "Utilities", emoji: "💡", available: Decimal(string: "60.00") ?? 60),
            .init(name: "Clothing", emoji: "👕", available: Decimal(string: "40.00") ?? 40),
        ],
        currencyCode: "GBP"
    )
}
