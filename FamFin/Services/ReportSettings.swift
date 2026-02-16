import Foundation

/// Which accounts a chart includes by default before manual exclusions.
enum AccountFilter: String, Codable, Equatable {
    /// All accounts (budget + tracking).
    case all
    /// Only budget accounts.
    case budgetOnly
    /// Only tracking accounts.
    case trackingOnly
}

/// A single chart configuration on the Reports tab.
struct ChartConfig: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    /// Base filter applied before manual exclusions.
    var accountFilter: AccountFilter
    /// Account names that are *excluded* from this chart.
    /// Empty means "all accounts matching the filter are included".
    var excludedAccountNames: Set<String>
    /// Whether this is one of the three built-in charts that cannot be deleted.
    var isDefault: Bool

    init(
        id: UUID = UUID(),
        name: String,
        accountFilter: AccountFilter = .all,
        excludedAccountNames: Set<String> = [],
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.accountFilter = accountFilter
        self.excludedAccountNames = excludedAccountNames
        self.isDefault = isDefault
    }
}

/// Persisted configuration for the Reports tab.
struct ReportSettingsData: Codable, Equatable {
    var charts: [ChartConfig]

    /// Default charts: Budget Accounts, Tracking Accounts, Net Worth.
    static var `default`: ReportSettingsData {
        ReportSettingsData(charts: Self.defaultCharts)
    }

    static var defaultCharts: [ChartConfig] {
        [
            ChartConfig(name: "Budget Accounts", accountFilter: .budgetOnly, isDefault: true),
            ChartConfig(name: "Tracking Accounts", accountFilter: .trackingOnly, isDefault: true),
            ChartConfig(name: "Net Worth", accountFilter: .all, isDefault: true),
        ]
    }
}

/// Stores report chart configurations: order, names, and per-chart account exclusions.
/// Uses exclusion-based storage so newly created accounts automatically appear.
@MainActor
@Observable
class ReportSettings {
    private static let storageKey = "reportSettingsData_v5"

    var data: ReportSettingsData {
        didSet { save() }
    }

    init() {
        if let jsonString = UserDefaults.standard.string(forKey: Self.storageKey),
           let jsonData = jsonString.data(using: .utf8),
           var decoded = try? JSONDecoder().decode(ReportSettingsData.self, from: jsonData) {
            // Reset default charts to canonical definitions so filters and names stay correct
            let canonical = ReportSettingsData.defaultCharts
            for index in decoded.charts.indices where decoded.charts[index].isDefault {
                let id = decoded.charts[index].id
                let filter = decoded.charts[index].accountFilter
                if let match = canonical.first(where: { $0.accountFilter == filter }) {
                    decoded.charts[index] = match
                    decoded.charts[index].id = id
                }
            }
            self.data = decoded
        } else {
            self.data = .default
        }
    }

    private func save() {
        guard let jsonData = try? JSONEncoder().encode(data),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        UserDefaults.standard.set(jsonString, forKey: Self.storageKey)
    }

    // MARK: - Charts

    var charts: [ChartConfig] {
        get { data.charts }
        set { data.charts = newValue }
    }

    @discardableResult
    func addChart(name: String) -> ChartConfig {
        let chart = ChartConfig(name: name)
        data.charts.append(chart)
        return chart
    }

    func deleteChart(at offsets: IndexSet) {
        let safeOffsets = offsets.filter { !data.charts[$0].isDefault }
        data.charts.remove(atOffsets: IndexSet(safeOffsets))
    }

    func moveChart(from source: IndexSet, to destination: Int) {
        data.charts.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Account Exclusions

    func excludedNames(for chartID: UUID) -> Set<String> {
        data.charts.first { $0.id == chartID }?.excludedAccountNames ?? []
    }

    func isExcluded(_ accountName: String, from chartID: UUID) -> Bool {
        excludedNames(for: chartID).contains(accountName)
    }

    /// Whether an account is actually included in the chart output,
    /// considering both the account filter and manual exclusions.
    func isIncluded(_ accountName: String, isBudget: Bool, in chartID: UUID) -> Bool {
        guard let chart = data.charts.first(where: { $0.id == chartID }) else { return false }
        switch chart.accountFilter {
        case .budgetOnly where !isBudget: return false
        case .trackingOnly where isBudget: return false
        default: break
        }
        return !chart.excludedAccountNames.contains(accountName)
    }

    func toggleAccount(_ accountName: String, for chartID: UUID) {
        guard let index = data.charts.firstIndex(where: { $0.id == chartID }),
              !data.charts[index].isDefault else { return }
        if data.charts[index].excludedAccountNames.contains(accountName) {
            data.charts[index].excludedAccountNames.remove(accountName)
        } else {
            data.charts[index].excludedAccountNames.insert(accountName)
        }
    }
}
