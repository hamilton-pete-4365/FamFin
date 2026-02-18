import Foundation

/// Parses CSV data into an array of `ImportedTransaction` values.
/// Supports configurable column mapping, multiple date formats, and
/// common CSV quoting conventions.
struct CSVParser: Sendable {

    // MARK: - Column mapping

    /// Describes which CSV column index maps to each transaction field.
    struct ColumnMapping: Sendable {
        var dateColumn: Int
        var amountColumn: Int
        var payeeColumn: Int
        var memoColumn: Int?

        /// The date format string used by this CSV file.
        var dateFormat: DateFormatOption

        /// Whether the first row is a header that should be skipped.
        var hasHeader: Bool
    }

    /// Supported date format patterns.
    enum DateFormatOption: String, CaseIterable, Identifiable, Sendable {
        case ddMMyyyySlash = "dd/MM/yyyy"
        case MMddyyyySlash = "MM/dd/yyyy"
        case yyyyMMddDash = "yyyy-MM-dd"
        case ddMMyyyyDash = "dd-MM-yyyy"
        case MMddyyyyDash = "MM-dd-yyyy"
        case yyyyMMddSlash = "yyyy/MM/dd"
        case ddDotMMDotyyyy = "dd.MM.yyyy"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .ddMMyyyySlash:    return "DD/MM/YYYY"
            case .MMddyyyySlash:    return "MM/DD/YYYY"
            case .yyyyMMddDash:     return "YYYY-MM-DD"
            case .ddMMyyyyDash:     return "DD-MM-YYYY"
            case .MMddyyyyDash:     return "MM-DD-YYYY"
            case .yyyyMMddSlash:    return "YYYY/MM/DD"
            case .ddDotMMDotyyyy:   return "DD.MM.YYYY"
            }
        }
    }

    // MARK: - Parsing

    /// Parse raw CSV data into rows of string columns.
    /// Returns the column arrays without interpreting their meaning.
    static func parseRawRows(from data: Data) -> [[String]] {
        guard let content = String(data: data, encoding: .utf8) ??
                            String(data: data, encoding: .isoLatin1) else {
            return []
        }
        return parseRawRows(from: content)
    }

    /// Parse a CSV string into rows of string columns.
    static func parseRawRows(from content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentField = ""
        var currentRow: [String] = []
        var insideQuotes = false

        let chars = Array(content)
        var i = 0

        while i < chars.count {
            let char = chars[i]

            if insideQuotes {
                if char == "\"" {
                    // Check for escaped quote (double-quote)
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                        continue
                    } else {
                        insideQuotes = false
                        i += 1
                        continue
                    }
                } else {
                    currentField.append(char)
                    i += 1
                    continue
                }
            }

            switch char {
            case "\"":
                insideQuotes = true
            case ",":
                currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            case "\r":
                // Handle \r\n or lone \r
                currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
                if !currentRow.allSatisfy({ $0.isEmpty }) {
                    rows.append(currentRow)
                }
                currentRow = []
                if i + 1 < chars.count && chars[i + 1] == "\n" {
                    i += 1
                }
            case "\n":
                currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
                if !currentRow.allSatisfy({ $0.isEmpty }) {
                    rows.append(currentRow)
                }
                currentRow = []
            default:
                currentField.append(char)
            }
            i += 1
        }

        // Flush the last field/row
        currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
        if !currentRow.allSatisfy({ $0.isEmpty }) {
            rows.append(currentRow)
        }

        return rows
    }

    /// Detect the number of columns in the CSV by looking at the most common column count.
    static func detectColumnCount(rows: [[String]]) -> Int {
        let counts = rows.map(\.count)
        let frequency = Dictionary(grouping: counts, by: { $0 })
        return frequency.max(by: { $0.value.count < $1.value.count })?.key ?? 0
    }

    /// Guess whether the first row is a header by checking if any cell looks numeric.
    static func firstRowLooksLikeHeader(rows: [[String]]) -> Bool {
        guard let firstRow = rows.first, rows.count > 1 else { return false }
        // If none of the cells in the first row parse as a number, it is likely a header.
        let hasNumber = firstRow.contains { cell in
            let cleaned = cell.replacing(",", with: "")
            return Decimal(string: cleaned) != nil && !cleaned.isEmpty
        }
        return !hasNumber
    }

    /// Attempt to auto-detect the date format by trying each format against the first
    /// few data rows at a given column index.
    static func detectDateFormat(rows: [[String]], dateColumn: Int) -> DateFormatOption {
        let sampleRows = rows.prefix(10)
        for format in DateFormatOption.allCases {
            let formatter = makeDateFormatter(for: format)
            let matches = sampleRows.filter { row in
                guard dateColumn < row.count else { return false }
                return formatter.date(from: row[dateColumn].trimmingCharacters(in: .whitespaces)) != nil
            }
            if matches.count == sampleRows.count {
                return format
            }
        }
        // Default to a common format
        return .ddMMyyyySlash
    }

    /// Parse CSV data into `ImportedTransaction` values using the provided column mapping.
    static func parse(data: Data, mapping: ColumnMapping) -> [ImportedTransaction] {
        let rows = parseRawRows(from: data)
        return parse(rows: rows, mapping: mapping)
    }

    /// Parse already-split rows into `ImportedTransaction` values.
    static func parse(rows: [[String]], mapping: ColumnMapping) -> [ImportedTransaction] {
        let dataRows = mapping.hasHeader ? Array(rows.dropFirst()) : rows
        let dateFormatter = makeDateFormatter(for: mapping.dateFormat)

        var transactions: [ImportedTransaction] = []

        for row in dataRows {
            guard mapping.dateColumn < row.count,
                  mapping.amountColumn < row.count,
                  mapping.payeeColumn < row.count else { continue }

            // Parse date
            let dateString = row[mapping.dateColumn].trimmingCharacters(in: .whitespaces)
            guard let date = dateFormatter.date(from: dateString) else { continue }

            // Parse amount — handle negatives, parentheses, and currency symbols
            let rawAmount = row[mapping.amountColumn]
                .trimmingCharacters(in: .whitespaces)
            guard let (amount, isExpense) = parseAmount(rawAmount) else { continue }

            // Parse payee
            let payee = row[mapping.payeeColumn].trimmingCharacters(in: .whitespaces)
            guard !payee.isEmpty else { continue }

            // Parse memo (optional)
            var memo = ""
            if let memoCol = mapping.memoColumn, memoCol < row.count {
                memo = row[memoCol].trimmingCharacters(in: .whitespaces)
            }

            // Build a reference from the row content for duplicate detection
            let reference = "\(dateString)_\(rawAmount)_\(payee)"

            let transaction = ImportedTransaction(
                date: date,
                amount: amount,
                payee: payee,
                memo: memo,
                reference: reference,
                isExpense: isExpense
            )
            transactions.append(transaction)
        }

        return transactions
    }

    // MARK: - Amount parsing

    /// Parse an amount string, handling negative signs, parentheses, and currency symbols.
    /// Returns the absolute amount and whether it represents an expense (negative).
    static func parseAmount(_ raw: String) -> (Decimal, Bool)? {
        var cleaned = raw.trimmingCharacters(in: .whitespaces)

        // Detect parenthetical negatives: (100.00) -> -100.00
        let isParenNegative = cleaned.hasPrefix("(") && cleaned.hasSuffix(")")
        if isParenNegative {
            cleaned = String(cleaned.dropFirst().dropLast())
        }

        // Detect leading negative sign
        let isNegative = cleaned.hasPrefix("-") || isParenNegative
        cleaned = cleaned.replacing("-", with: "")

        // Strip common currency symbols and whitespace
        let currencySymbols: [String] = ["$", "£", "€", "¥", "₹", "kr", "CHF", "R$", "A$", "C$"]
        for symbol in currencySymbols {
            cleaned = cleaned.replacing(symbol, with: "")
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)

        // Remove thousands separators (commas)
        cleaned = cleaned.replacing(",", with: "")

        guard let decimal = Decimal(string: cleaned), decimal != .zero else {
            return nil
        }

        let absAmount = decimal < 0 ? -decimal : decimal
        return (absAmount, isNegative)
    }

    // MARK: - Helpers

    /// Create a DateFormatter configured for the given format option.
    static func makeDateFormatter(for option: DateFormatOption) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = option.rawValue
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }
}
