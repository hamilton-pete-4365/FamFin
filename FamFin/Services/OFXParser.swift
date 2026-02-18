import Foundation

/// Parses OFX/QFX (Open Financial Exchange) files into `ImportedTransaction` values.
/// Supports both OFX 1.x (SGML) and OFX 2.x (XML) formats.
struct OFXParser: Sendable {

    // MARK: - Errors

    enum OFXError: LocalizedError {
        case invalidData
        case noTransactionsFound

        var errorDescription: String? {
            switch self {
            case .invalidData:
                return "The file does not appear to be a valid OFX/QFX file."
            case .noTransactionsFound:
                return "No transactions were found in the OFX file."
            }
        }
    }

    // MARK: - Parsing

    /// Parse OFX data into an array of `ImportedTransaction`.
    static func parse(data: Data) throws -> [ImportedTransaction] {
        guard let content = String(data: data, encoding: .utf8) ??
                            String(data: data, encoding: .isoLatin1) ??
                            String(data: data, encoding: .ascii) else {
            throw OFXError.invalidData
        }

        let transactions = parseTransactions(from: content)

        if transactions.isEmpty {
            throw OFXError.noTransactionsFound
        }

        return transactions
    }

    /// Extract all `<STMTTRN>` blocks from the OFX content and parse each one.
    private static func parseTransactions(from content: String) -> [ImportedTransaction] {
        var transactions: [ImportedTransaction] = []

        // Find all STMTTRN blocks — works for both SGML and XML style
        let blocks = extractBlocks(tag: "STMTTRN", from: content)

        for block in blocks {
            guard let transaction = parseTransactionBlock(block) else { continue }
            transactions.append(transaction)
        }

        return transactions
    }

    /// Parse a single `<STMTTRN>...</STMTTRN>` block into an `ImportedTransaction`.
    private static func parseTransactionBlock(_ block: String) -> ImportedTransaction? {
        // Extract fields using tag-value extraction
        let trnType = extractValue(tag: "TRNTYPE", from: block) ?? "DEBIT"
        let datePosted = extractValue(tag: "DTPOSTED", from: block) ?? ""
        let amountString = extractValue(tag: "TRNAMT", from: block) ?? ""
        let fitID = extractValue(tag: "FITID", from: block) ?? UUID().uuidString
        let name = extractValue(tag: "NAME", from: block) ?? ""
        let memo = extractValue(tag: "MEMO", from: block) ?? ""

        // Parse date — OFX dates are in YYYYMMDDHHMMSS[.XXX:TZ] format
        guard let date = parseOFXDate(datePosted) else { return nil }

        // Parse amount
        let cleanedAmount = amountString
            .trimmingCharacters(in: .whitespaces)
            .replacing(",", with: "")
        guard let decimalAmount = Decimal(string: cleanedAmount) else { return nil }

        let isExpense = decimalAmount < 0 || trnType.uppercased() == "DEBIT"
        let absAmount = decimalAmount < 0 ? -decimalAmount : decimalAmount

        guard absAmount > 0 else { return nil }

        // Use NAME as payee; fall back to MEMO if NAME is empty
        let payee = name.isEmpty ? (memo.isEmpty ? "Unknown" : memo) : name
        let memoText = name.isEmpty ? "" : memo

        return ImportedTransaction(
            date: date,
            amount: absAmount,
            payee: payee,
            memo: memoText,
            reference: fitID,
            isExpense: isExpense
        )
    }

    // MARK: - OFX date parsing

    /// Parse an OFX date string. OFX dates use the format `YYYYMMDD[HHMMSS[.XXX]][:tz]`.
    /// Examples: `20240115`, `20240115120000`, `20240115120000.000[0:GMT]`
    private static func parseOFXDate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 8 else { return nil }

        // Take just the first 8 characters for the date portion
        let dateOnly = String(trimmed.prefix(8))

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current

        return formatter.date(from: dateOnly)
    }

    // MARK: - SGML/XML tag extraction

    /// Extract all blocks of content between `<TAG>` and `</TAG>`.
    /// Handles both XML-style `<TAG>...</TAG>` and SGML-style where closing tags may be absent.
    private static func extractBlocks(tag: String, from content: String) -> [String] {
        var blocks: [String] = []
        let openTag = "<\(tag)>"
        let closeTag = "</\(tag)>"

        var searchRange = content.startIndex..<content.endIndex

        while let openRange = content.range(of: openTag, options: .caseInsensitive, range: searchRange) {
            let afterOpen = openRange.upperBound

            if let closeRange = content.range(of: closeTag, options: .caseInsensitive, range: afterOpen..<content.endIndex) {
                let blockContent = String(content[afterOpen..<closeRange.lowerBound])
                blocks.append(blockContent)
                searchRange = closeRange.upperBound..<content.endIndex
            } else {
                // SGML mode: no closing tag, take everything until the next open tag of the same type or end
                if let nextOpen = content.range(of: openTag, options: .caseInsensitive, range: afterOpen..<content.endIndex) {
                    let blockContent = String(content[afterOpen..<nextOpen.lowerBound])
                    blocks.append(blockContent)
                    searchRange = nextOpen.lowerBound..<content.endIndex
                } else {
                    let blockContent = String(content[afterOpen..<content.endIndex])
                    blocks.append(blockContent)
                    break
                }
            }
        }

        return blocks
    }

    /// Extract the value for a given OFX tag.
    /// Handles both:
    /// - SGML style: `<TAG>value\n`
    /// - XML style: `<TAG>value</TAG>`
    private static func extractValue(tag: String, from content: String) -> String? {
        let openTag = "<\(tag)>"
        let closeTag = "</\(tag)>"

        guard let openRange = content.range(of: openTag, options: .caseInsensitive) else {
            return nil
        }

        let afterOpen = openRange.upperBound
        let remaining = content[afterOpen...]

        // Try XML-style first: look for closing tag
        if let closeRange = remaining.range(of: closeTag, options: .caseInsensitive) {
            let value = String(remaining[..<closeRange.lowerBound])
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // SGML style: value ends at the next tag or newline
        var value = ""
        for char in remaining {
            if char == "<" || char == "\n" || char == "\r" {
                break
            }
            value.append(char)
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
