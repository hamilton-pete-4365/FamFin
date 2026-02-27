import SwiftUI

/// A calendar date picker backed by `UICalendarView` that calls back on every
/// tap — including re-selection of the already-chosen date. This also avoids
/// the month-chevron dropdown that the SwiftUI `.graphical` `DatePicker` shows.
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

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        selection.selectedDate = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: selectedDate
        )
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
        guard let selection = uiView.selectionBehavior as? UICalendarSelectionSingleDate else {
            return
        }

        let newComponents = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: selectedDate
        )

        if selection.selectedDate != newComponents {
            selection.selectedDate = newComponents
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UICalendarSelectionSingleDateDelegate {
        var parent: CalendarDatePicker

        init(_ parent: CalendarDatePicker) {
            self.parent = parent
        }

        func dateSelection(
            _ selection: UICalendarSelectionSingleDate,
            didSelectDate dateComponents: DateComponents?
        ) {
            if let dateComponents,
               let date = Calendar.current.date(from: dateComponents) {
                parent.selectedDate = date
            } else {
                // The user tapped the already-selected date (UIKit treats it as
                // deselection). Re-apply the selection so the circle stays visible.
                let components = Calendar.current.dateComponents(
                    [.year, .month, .day],
                    from: parent.selectedDate
                )
                selection.selectedDate = components
            }

            parent.onDateSelected()
        }
    }
}
