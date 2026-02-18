import Foundation
import Testing
@testable import FamFin

// MARK: - ReportSettingsData Tests

@Suite("ReportSettingsData defaults")
struct ReportSettingsDataTests {

    @Test("Default settings have 3 charts")
    func defaultChartCount() {
        let settings = ReportSettingsData.default
        #expect(settings.charts.count == 3)
    }

    @Test("Default charts are Budget Accounts, Tracking Accounts, Net Worth")
    func defaultChartNames() {
        let charts = ReportSettingsData.defaultCharts
        #expect(charts[0].name == "Budget Accounts")
        #expect(charts[1].name == "Tracking Accounts")
        #expect(charts[2].name == "Net Worth")
    }

    @Test("Default charts have correct account filters")
    func defaultChartFilters() {
        let charts = ReportSettingsData.defaultCharts
        #expect(charts[0].accountFilter == .budgetOnly)
        #expect(charts[1].accountFilter == .trackingOnly)
        #expect(charts[2].accountFilter == .all)
    }

    @Test("Default charts are all marked as default")
    func defaultChartsAreDefault() {
        let charts = ReportSettingsData.defaultCharts
        for chart in charts {
            #expect(chart.isDefault == true, "\(chart.name) should be marked as default")
        }
    }

    @Test("Default charts have no exclusions")
    func defaultChartsNoExclusions() {
        let charts = ReportSettingsData.defaultCharts
        for chart in charts {
            #expect(chart.excludedAccountNames.isEmpty, "\(chart.name) should have no exclusions")
        }
    }
}

// MARK: - ChartConfig Tests

@Suite("ChartConfig model")
struct ChartConfigTests {

    @Test("ChartConfig has unique IDs")
    func uniqueIDs() {
        let chart1 = ChartConfig(name: "Test 1")
        let chart2 = ChartConfig(name: "Test 2")
        #expect(chart1.id != chart2.id)
    }

    @Test("ChartConfig defaults to all accounts filter")
    func defaultFilter() {
        let chart = ChartConfig(name: "Custom")
        #expect(chart.accountFilter == .all)
    }

    @Test("ChartConfig defaults to not default")
    func defaultIsNotDefault() {
        let chart = ChartConfig(name: "Custom")
        #expect(chart.isDefault == false)
    }

    @Test("ChartConfig defaults to empty exclusions")
    func defaultEmptyExclusions() {
        let chart = ChartConfig(name: "Custom")
        #expect(chart.excludedAccountNames.isEmpty)
    }
}

// MARK: - AccountFilter Tests

@Suite("AccountFilter")
struct AccountFilterTests {

    @Test("All filter raw values are correct")
    func rawValues() {
        #expect(AccountFilter.all.rawValue == "all")
        #expect(AccountFilter.budgetOnly.rawValue == "budgetOnly")
        #expect(AccountFilter.trackingOnly.rawValue == "trackingOnly")
    }

    @Test("AccountFilter round-trips through Codable")
    func codableRoundTrip() throws {
        for filter in [AccountFilter.all, .budgetOnly, .trackingOnly] {
            let encoded = try JSONEncoder().encode(filter)
            let decoded = try JSONDecoder().decode(AccountFilter.self, from: encoded)
            #expect(decoded == filter)
        }
    }
}

// MARK: - ReportSettings Logic Tests

@Suite("ReportSettings logic")
struct ReportSettingsLogicTests {

    @MainActor @Test("addChart appends a new chart")
    func addChart() {
        let settings = ReportSettings()
        let initialCount = settings.charts.count
        settings.addChart(name: "Custom Chart")
        #expect(settings.charts.count == initialCount + 1)
        #expect(settings.charts.last?.name == "Custom Chart")
    }

    @MainActor @Test("deleteChart does not delete default charts")
    func deleteDefaultChart() {
        let settings = ReportSettings()
        let initialCount = settings.charts.count
        // Try to delete the first chart (which is default)
        settings.deleteChart(at: IndexSet(integer: 0))
        #expect(settings.charts.count == initialCount)
    }

    @MainActor @Test("deleteChart deletes non-default charts")
    func deleteCustomChart() {
        let settings = ReportSettings()
        settings.addChart(name: "Custom")
        let countBeforeDelete = settings.charts.count
        let lastIndex = countBeforeDelete - 1
        settings.deleteChart(at: IndexSet(integer: lastIndex))
        #expect(settings.charts.count == countBeforeDelete - 1)
    }

    @MainActor @Test("isIncluded respects budgetOnly filter")
    func isIncludedBudgetOnly() {
        let settings = ReportSettings()
        // First chart is "Budget Accounts" with budgetOnly filter
        let chartID = settings.charts[0].id

        #expect(settings.isIncluded("Current", isBudget: true, in: chartID) == true)
        #expect(settings.isIncluded("Mortgage", isBudget: false, in: chartID) == false)
    }

    @MainActor @Test("isIncluded respects trackingOnly filter")
    func isIncludedTrackingOnly() {
        let settings = ReportSettings()
        // Second chart is "Tracking Accounts" with trackingOnly filter
        let chartID = settings.charts[1].id

        #expect(settings.isIncluded("Mortgage", isBudget: false, in: chartID) == true)
        #expect(settings.isIncluded("Current", isBudget: true, in: chartID) == false)
    }

    @MainActor @Test("isIncluded respects all filter")
    func isIncludedAll() {
        let settings = ReportSettings()
        // Third chart is "Net Worth" with all filter
        let chartID = settings.charts[2].id

        #expect(settings.isIncluded("Current", isBudget: true, in: chartID) == true)
        #expect(settings.isIncluded("Mortgage", isBudget: false, in: chartID) == true)
    }

    @MainActor @Test("toggleAccount adds and removes exclusions on custom charts")
    func toggleAccount() {
        let settings = ReportSettings()
        let chart = settings.addChart(name: "Custom")
        let chartID = chart.id

        // Initially included
        #expect(settings.isExcluded("MyAccount", from: chartID) == false)

        // Toggle to exclude
        settings.toggleAccount("MyAccount", for: chartID)
        #expect(settings.isExcluded("MyAccount", from: chartID) == true)

        // Toggle back to include
        settings.toggleAccount("MyAccount", for: chartID)
        #expect(settings.isExcluded("MyAccount", from: chartID) == false)
    }

    @MainActor @Test("toggleAccount does nothing on default charts")
    func toggleAccountDefaultChart() {
        let settings = ReportSettings()
        let chartID = settings.charts[0].id // default chart

        settings.toggleAccount("SomeAccount", for: chartID)
        #expect(settings.isExcluded("SomeAccount", from: chartID) == false)
    }

    @MainActor @Test("excludedNames returns empty set for unknown chart ID")
    func excludedNamesUnknownChart() {
        let settings = ReportSettings()
        let excluded = settings.excludedNames(for: UUID())
        #expect(excluded.isEmpty)
    }

    @MainActor @Test("isIncluded returns false for unknown chart ID")
    func isIncludedUnknownChart() {
        let settings = ReportSettings()
        #expect(settings.isIncluded("Any", isBudget: true, in: UUID()) == false)
    }
}
