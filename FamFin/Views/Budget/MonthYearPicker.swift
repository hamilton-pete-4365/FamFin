import SwiftUI

/// A compact month/year picker presented as a popover.
/// Shows a 4x3 grid of months for the displayed year with year navigation.
struct MonthYearPicker: View {
    @Binding var selectedMonth: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var displayedYear: Int

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 4)

    init(selectedMonth: Binding<Date>) {
        self._selectedMonth = selectedMonth
        let year = Calendar.current.component(.year, from: selectedMonth.wrappedValue)
        self._displayedYear = State(initialValue: year)
    }

    private var selectedYear: Int {
        calendar.component(.year, from: selectedMonth)
    }

    private var selectedMonthNumber: Int {
        calendar.component(.month, from: selectedMonth)
    }

    private var currentYear: Int {
        calendar.component(.year, from: Date())
    }

    private var currentMonthNumber: Int {
        calendar.component(.month, from: Date())
    }

    var body: some View {
        VStack(spacing: 16) {
            yearHeader
            monthGrid
        }
        .padding()
        .frame(width: 280)
    }

    // MARK: - Year Header

    private var yearHeader: some View {
        HStack {
            Button("Previous year", systemImage: "chevron.left") {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    displayedYear -= 1
                }
            }
            .labelStyle(.iconOnly)
            .font(.body.bold())
            .accessibilityHint("Double tap to show the previous year")

            Spacer()

            Text(String(displayedYear))
                .font(.headline)
                .monospacedDigit()
                .contentTransition(reduceMotion ? .identity : .numericText())

            Spacer()

            Button("Next year", systemImage: "chevron.right") {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    displayedYear += 1
                }
            }
            .labelStyle(.iconOnly)
            .font(.body.bold())
            .accessibilityHint("Double tap to show the next year")
        }
    }

    // MARK: - Month Grid

    private var monthGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...12, id: \.self) { month in
                let isSelected = displayedYear == selectedYear && month == selectedMonthNumber
                let isCurrent = displayedYear == currentYear && month == currentMonthNumber

                Button {
                    selectMonth(month)
                } label: {
                    Text(abbreviatedMonthName(month))
                        .font(.subheadline)
                        .bold(isSelected)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            isSelected
                                ? Color.accentColor
                                : Color.clear
                        )
                        .foregroundStyle(
                            isSelected
                                ? .white
                                : isCurrent ? Color.accentColor : .primary
                        )
                        .clipShape(.rect(cornerRadius: 8))
                        .overlay {
                            if isCurrent && !isSelected {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1)
                            }
                        }
                }
                .accessibilityLabel("\(fullMonthName(month)) \(displayedYear)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select this month")
            }
        }
    }

    // MARK: - Helpers

    private func selectMonth(_ month: Int) {
        var components = DateComponents()
        components.year = displayedYear
        components.month = month
        components.day = 1
        if let date = calendar.date(from: components) {
            selectedMonth = date
            dismiss()
        }
    }

    private func abbreviatedMonthName(_ month: Int) -> String {
        calendar.shortMonthSymbols[month - 1]
    }

    private func fullMonthName(_ month: Int) -> String {
        calendar.monthSymbols[month - 1]
    }
}
