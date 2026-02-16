import SwiftUI
import SwiftData

struct ReportSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var settings: ReportSettings

    @State private var accountPickerChartID: UUID?
    @State private var focusNewChartName = false

    private var allAccounts: [Account] {
        (try? modelContext.fetch(
            FetchDescriptor<Account>(sortBy: [SortDescriptor(\Account.sortOrder)])
        )) ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                ChartsSection(
                    settings: settings,
                    onSelectAccounts: { chartID in
                        accountPickerChartID = chartID
                    },
                    onAddChart: { chartID in
                        focusNewChartName = true
                        accountPickerChartID = chartID
                    }
                )
            }
            .navigationTitle("Report Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $accountPickerChartID) { chartID in
                AccountPickerSheet(
                    settings: settings,
                    chartID: chartID,
                    accounts: allAccounts,
                    focusName: focusNewChartName
                )
                .onDisappear {
                    focusNewChartName = false
                }
            }
        }
    }
}

// MARK: - Make UUID work with sheet(item:)

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

// MARK: - Charts Section

struct ChartsSection: View {
    var settings: ReportSettings
    var onSelectAccounts: (UUID) -> Void
    var onAddChart: (UUID) -> Void

    var body: some View {
        Section {
            ForEach(settings.charts) { chart in
                ChartRow(
                    chart: chart,
                    onSelectAccounts: { onSelectAccounts(chart.id) },
                    onDelete: chart.isDefault ? nil : {
                        if let index = settings.charts.firstIndex(where: { $0.id == chart.id }) {
                            settings.deleteChart(at: IndexSet(integer: index))
                        }
                    }
                )
            }
            .onMove { source, destination in
                settings.moveChart(from: source, to: destination)
            }

            Button {
                let newChart = settings.addChart(name: "New Chart")
                onAddChart(newChart.id)
            } label: {
                HStack {
                    Text("Add New Chart")
                    Spacer()
                    Image(systemName: "plus")
                }
            }
        } header: {
            Text("Charts")
        }
    }
}

// MARK: - Chart Row

struct ChartRow: View {
    let chart: ChartConfig
    var onSelectAccounts: () -> Void
    var onDelete: (() -> Void)?

    private var subtitle: String? {
        guard chart.isDefault else { return nil }
        switch chart.accountFilter {
        case .budgetOnly: return "Includes all budget accounts"
        case .trackingOnly: return "Includes all tracking accounts"
        case .all: return "Includes all accounts"
        }
    }

    var body: some View {
        if chart.isDefault {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(chart.name)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        } else {
            Button {
                onSelectAccounts()
            } label: {
                HStack {
                    Text(chart.name)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if let onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
}

// MARK: - Account Picker Sheet

struct AccountPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var settings: ReportSettings
    let chartID: UUID
    let accounts: [Account]
    var focusName: Bool = false

    @State private var editedName: String = ""
    @FocusState private var nameFieldFocused: Bool

    private var chartIndex: Int? {
        settings.charts.firstIndex { $0.id == chartID }
    }

    private var budgetAccounts: [Account] {
        accounts.filter(\.isBudget)
    }

    private var trackingAccounts: [Account] {
        accounts.filter { !$0.isBudget }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Chart name", text: $editedName)
                        .focused($nameFieldFocused)
                        .onSubmit { commitRename() }
                }

                if !budgetAccounts.isEmpty {
                    Section("Budget Accounts") {
                        ForEach(budgetAccounts) { account in
                            AccountToggleRow(
                                accountName: account.name,
                                isIncluded: settings.isIncluded(account.name, isBudget: true, in: chartID),
                                onToggle: { settings.toggleAccount(account.name, for: chartID) }
                            )
                        }
                    }
                }

                if !trackingAccounts.isEmpty {
                    Section("Tracking Accounts") {
                        ForEach(trackingAccounts) { account in
                            AccountToggleRow(
                                accountName: account.name,
                                isIncluded: settings.isIncluded(account.name, isBudget: false, in: chartID),
                                onToggle: { settings.toggleAccount(account.name, for: chartID) }
                            )
                        }
                    }
                }
            }
            .navigationTitle(editedName.isEmpty ? "Chart" : editedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitRename()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let index = chartIndex {
                    editedName = settings.charts[index].name
                }
                if focusName {
                    nameFieldFocused = true
                }
            }
        }
    }

    private func commitRename() {
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let index = chartIndex {
            settings.charts[index].name = trimmed
        }
    }
}

// MARK: - Account Toggle Row

struct AccountToggleRow: View {
    let accountName: String
    let isIncluded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack {
                Text(accountName)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isIncluded ? Color.accentColor : .secondary)
            }
        }
    }
}
