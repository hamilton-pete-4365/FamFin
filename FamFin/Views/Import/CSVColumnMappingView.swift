import SwiftUI
import SwiftData

/// Lets the user map CSV columns to transaction fields before import.
/// Shows a preview of the data and pickers for each field mapping.
struct CSVColumnMappingView: View {
    @Environment(\.modelContext) private var modelContext

    let rawData: Data
    let rows: [[String]]
    let onImportComplete: (Int) -> Void

    @State private var hasHeader: Bool = true
    @State private var dateColumn: Int = 0
    @State private var amountColumn: Int = 1
    @State private var payeeColumn: Int = 2
    @State private var memoColumn: Int? = nil
    @State private var dateFormat: CSVParser.DateFormatOption = .ddMMyyyySlash
    @State private var parsedTransactions: [ImportedTransaction] = []
    @State private var showReview = false

    /// The number of columns detected in the CSV.
    private var columnCount: Int {
        CSVParser.detectColumnCount(rows: rows)
    }

    /// The first row (used for headers or preview).
    private var headerRow: [String]? {
        rows.first
    }

    /// Preview rows (skip header if present).
    private var previewRows: [[String]] {
        let dataRows = hasHeader ? Array(rows.dropFirst()) : rows
        return Array(dataRows.prefix(5))
    }

    /// Column options for pickers.
    private var columnOptions: [Int] {
        Array(0..<columnCount)
    }

    /// Label for a column — uses header text if available, otherwise "Column N".
    private func columnLabel(_ index: Int) -> String {
        if hasHeader, let header = headerRow, index < header.count {
            let name = header[index]
            if !name.isEmpty {
                return "\(name) (col \(index + 1))"
            }
        }
        return "Column \(index + 1)"
    }

    var body: some View {
        Form {
            CSVPreviewSection(
                hasHeader: hasHeader,
                headerRow: headerRow,
                previewRows: previewRows,
                columnCount: columnCount
            )

            Section("Options") {
                Toggle("First row is header", isOn: $hasHeader)
            }

            CSVMappingSection(
                dateColumn: $dateColumn,
                amountColumn: $amountColumn,
                payeeColumn: $payeeColumn,
                memoColumn: $memoColumn,
                dateFormat: $dateFormat,
                columnOptions: columnOptions,
                columnLabel: columnLabel
            )

            CSVMappingPreviewSection(
                previewRows: previewRows,
                dateColumn: dateColumn,
                amountColumn: amountColumn,
                payeeColumn: payeeColumn,
                memoColumn: memoColumn,
                dateFormat: dateFormat
            )
        }
        .navigationTitle("Map Columns")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Continue") {
                    parseAndContinue()
                }
            }
        }
        .navigationDestination(isPresented: $showReview) {
            ImportReviewView(
                transactions: parsedTransactions,
                onImportComplete: onImportComplete
            )
        }
        .onAppear {
            autoDetectSettings()
        }
    }

    /// Attempt to auto-detect header, date format, and column assignments.
    private func autoDetectSettings() {
        hasHeader = CSVParser.firstRowLooksLikeHeader(rows: rows)

        // Try to guess column assignments from header names
        if hasHeader, let header = headerRow {
            for (index, name) in header.enumerated() {
                let lower = name.lowercased()
                if lower.localizedStandardContains("date") {
                    dateColumn = index
                } else if lower.localizedStandardContains("amount") ||
                          lower.localizedStandardContains("value") ||
                          lower.localizedStandardContains("debit") ||
                          lower.localizedStandardContains("credit") {
                    amountColumn = index
                } else if lower.localizedStandardContains("payee") ||
                          lower.localizedStandardContains("description") ||
                          lower.localizedStandardContains("name") ||
                          lower.localizedStandardContains("merchant") {
                    payeeColumn = index
                } else if lower.localizedStandardContains("memo") ||
                          lower.localizedStandardContains("reference") ||
                          lower.localizedStandardContains("note") {
                    memoColumn = index
                }
            }
        }

        // Auto-detect date format
        let dataRows = hasHeader ? Array(rows.dropFirst()) : rows
        if !dataRows.isEmpty {
            dateFormat = CSVParser.detectDateFormat(rows: dataRows, dateColumn: dateColumn)
        }
    }

    private func parseAndContinue() {
        let mapping = CSVParser.ColumnMapping(
            dateColumn: dateColumn,
            amountColumn: amountColumn,
            payeeColumn: payeeColumn,
            memoColumn: memoColumn,
            dateFormat: dateFormat,
            hasHeader: hasHeader
        )

        var transactions = CSVParser.parse(rows: rows, mapping: mapping)
        transactions = AutoCategorizer.categorize(transactions, context: modelContext)
        transactions = AutoCategorizer.detectDuplicates(transactions, context: modelContext)
        parsedTransactions = transactions
        showReview = true
    }
}

// MARK: - CSV data preview

/// Shows the first few rows of raw CSV data in a scrollable table.
private struct CSVPreviewSection: View {
    let hasHeader: Bool
    let headerRow: [String]?
    let previewRows: [[String]]
    let columnCount: Int

    var body: some View {
        Section("Data Preview") {
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header row
                    if hasHeader, let header = headerRow {
                        HStack(spacing: 0) {
                            ForEach(0..<min(header.count, columnCount), id: \.self) { col in
                                Text(header[col])
                                    .font(.caption)
                                    .bold()
                                    .frame(width: 120, alignment: .leading)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        Divider()
                    }

                    // Data rows
                    ForEach(previewRows.indices, id: \.self) { rowIndex in
                        let row = previewRows[rowIndex]
                        HStack(spacing: 0) {
                            ForEach(0..<min(row.count, columnCount), id: \.self) { col in
                                Text(row[col])
                                    .font(.caption)
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                            }
                        }
                        if rowIndex < previewRows.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Column mapping pickers

/// Pickers for assigning each transaction field to a CSV column.
private struct CSVMappingSection: View {
    @Binding var dateColumn: Int
    @Binding var amountColumn: Int
    @Binding var payeeColumn: Int
    @Binding var memoColumn: Int?
    @Binding var dateFormat: CSVParser.DateFormatOption

    let columnOptions: [Int]
    let columnLabel: (Int) -> String

    var body: some View {
        Section("Column Mapping") {
            Picker("Date", selection: $dateColumn) {
                ForEach(columnOptions, id: \.self) { index in
                    Text(columnLabel(index)).tag(index)
                }
            }

            Picker("Amount", selection: $amountColumn) {
                ForEach(columnOptions, id: \.self) { index in
                    Text(columnLabel(index)).tag(index)
                }
            }

            Picker("Payee", selection: $payeeColumn) {
                ForEach(columnOptions, id: \.self) { index in
                    Text(columnLabel(index)).tag(index)
                }
            }

            Picker("Memo", selection: $memoColumn) {
                Text("None").tag(Int?.none)
                ForEach(columnOptions, id: \.self) { index in
                    Text(columnLabel(index)).tag(Int?.some(index))
                }
            }

            Picker("Date Format", selection: $dateFormat) {
                ForEach(CSVParser.DateFormatOption.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
        }
    }
}

// MARK: - Mapping preview

/// Shows how the current column mapping interprets the first few data rows.
private struct CSVMappingPreviewSection: View {
    let previewRows: [[String]]
    let dateColumn: Int
    let amountColumn: Int
    let payeeColumn: Int
    let memoColumn: Int?
    let dateFormat: CSVParser.DateFormatOption

    var body: some View {
        Section("Mapping Preview") {
            if previewRows.isEmpty {
                Text("No data rows to preview.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(previewRows.prefix(3).indices, id: \.self) { index in
                    let row = previewRows[index]
                    MappingPreviewRow(
                        row: row,
                        dateColumn: dateColumn,
                        amountColumn: amountColumn,
                        payeeColumn: payeeColumn,
                        memoColumn: memoColumn,
                        dateFormat: dateFormat
                    )
                }
            }
        }
    }
}

/// A single preview row showing how column mapping interprets the data.
private struct MappingPreviewRow: View {
    let row: [String]
    let dateColumn: Int
    let amountColumn: Int
    let payeeColumn: Int
    let memoColumn: Int?
    let dateFormat: CSVParser.DateFormatOption

    private var dateText: String {
        guard dateColumn < row.count else { return "?" }
        return row[dateColumn]
    }

    private var amountText: String {
        guard amountColumn < row.count else { return "?" }
        return row[amountColumn]
    }

    private var payeeText: String {
        guard payeeColumn < row.count else { return "?" }
        return row[payeeColumn]
    }

    private var memoText: String {
        guard let col = memoColumn, col < row.count else { return "" }
        return row[col]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(payeeText, systemImage: "person")
                    .font(.subheadline)
                Spacer()
                Text(amountText)
                    .font(.subheadline)
                    .bold()
            }
            HStack {
                Text(dateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !memoText.isEmpty {
                    Text("- \(memoText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
