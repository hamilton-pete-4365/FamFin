import SwiftUI

/// A calendar date picker backed by `UICalendarView` that calls back on every
/// tap — including re-selection of the already-chosen date. This also avoids
/// the month-chevron dropdown that the SwiftUI `.graphical` `DatePicker` shows.
///
/// Uses `UICalendarSelectionMultiDate` (constrained to a single date) rather
/// than `UICalendarSelectionSingleDate` so that the explicit `didDeselectDate`
/// delegate callback fires when the user taps the already-selected date.
struct CalendarDatePicker: UIViewRepresentable {
    @Binding var selectedDate: Date
    var onDateSelected: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        calendarView.calendar = .current
        calendarView.availableDateRange = DateInterval(
            start: .distantPast,
            end: .distantFuture
        )

        let selection = UICalendarSelectionMultiDate(delegate: context.coordinator)
        selection.selectedDates = [
            Calendar.current.dateComponents(
                [.year, .month, .day],
                from: selectedDate
            )
        ]
        calendarView.selectionBehavior = selection

        calendarView.visibleDateComponents = Calendar.current.dateComponents(
            [.year, .month],
            from: selectedDate
        )

        // Let SwiftUI drive the width; the calendar's intrinsic height is fine.
        calendarView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return calendarView
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        context.coordinator.parent = self

        guard let selection = uiView.selectionBehavior as? UICalendarSelectionMultiDate else {
            return
        }

        let newComponents = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: selectedDate
        )

        if selection.selectedDates != [newComponents] {
            selection.selectedDates = [newComponents]
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UICalendarSelectionMultiDateDelegate {
        var parent: CalendarDatePicker

        init(_ parent: CalendarDatePicker) {
            self.parent = parent
        }

        func multiDateSelection(
            _ selection: UICalendarSelectionMultiDate,
            didSelectDate dateComponents: DateComponents
        ) {
            guard let date = Calendar.current.date(from: dateComponents) else { return }

            // Keep exactly one date selected.
            selection.selectedDates = [dateComponents]
            parent.selectedDate = date
            parent.onDateSelected()
        }

        func multiDateSelection(
            _ selection: UICalendarSelectionMultiDate,
            didDeselectDate dateComponents: DateComponents
        ) {
            // The user tapped the already-selected date. Re-apply the
            // selection so the circle stays visible and treat it as a
            // confirmation.
            selection.selectedDates = [dateComponents]
            parent.onDateSelected()
        }

        func multiDateSelection(
            _ selection: UICalendarSelectionMultiDate,
            canSelectDate dateComponents: DateComponents
        ) -> Bool {
            true
        }

        func multiDateSelection(
            _ selection: UICalendarSelectionMultiDate,
            canDeselectDate dateComponents: DateComponents
        ) -> Bool {
            true
        }
    }
}
