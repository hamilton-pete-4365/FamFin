import Foundation

/// Shared store for the currently selected budget month.
///
/// Both the Budget and Transactions tabs read and write the same month,
/// so switching tabs preserves the user's time-period context.
@MainActor
@Observable
final class SelectedMonthStore {
    var selectedMonth: Date

    init() {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        selectedMonth = cal.date(from: comps) ?? Date()
    }
}
