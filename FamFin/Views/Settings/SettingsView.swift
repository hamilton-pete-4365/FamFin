import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(CurrencySettings.key) private var currencyCode: String = "GBP"
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .auto

    @State private var exportDocument: BackupDocument?
    @State private var showingExportPicker = false
    @State private var exportError: String?
    @State private var showingImportPicker = false
    @State private var showingImportConfirm = false
    @State private var importURL: URL?
    @State private var importError: String?
    @State private var importSuccess = false

    private var currentCurrency: SupportedCurrency {
        SupportedCurrency(rawValue: currencyCode) ?? .gbp
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    appearanceSection
                    currencySection
                    dataSection
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileExporter(
                isPresented: $showingExportPicker,
                document: exportDocument,
                contentType: UTType.json,
                defaultFilename: exportDocument?.filename ?? "FamFin-backup.json"
            ) { result in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    exportError = error.localizedDescription
                }
                exportDocument = nil
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [UTType.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        importURL = url
                        showingImportConfirm = true
                    }
                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
            .alert("Restore from Backup?", isPresented: $showingImportConfirm) {
                Button("Cancel", role: .cancel) { importURL = nil }
                Button("Restore", role: .destructive) {
                    performImport()
                }
            } message: {
                Text("This will replace all your current data with the backup. This cannot be undone. Make sure you have exported a backup first if needed.")
            }
            .alert("Export Failed", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
            .alert("Restore Failed", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
            .alert("Restore Complete", isPresented: $importSuccess) {
                Button("OK") { }
            } message: {
                Text("Your data has been restored from the backup.")
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Picker("Appearance", selection: $appearanceMode) {
            ForEach(AppearanceMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .onChange(of: appearanceMode) { _, newMode in
            newMode.applyToAllWindows()
        }
    }

    // MARK: - Currency

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink {
                CurrencyPickerView(currencyCode: $currencyCode)
            } label: {
                HStack {
                    Text(currentCurrency.symbol)
                        .font(.title2)
                        .frame(width: 40)

                    Text(currentCurrency.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 12))
            }
            .padding(.horizontal)

            Text("Existing values are converted 1:1. No exchange rates are applied.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal)
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                Button {
                    exportData()
                } label: {
                    HStack {
                        Label("Export Backup", systemImage: "square.and.arrow.up")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }

                Divider()
                    .padding(.leading)

                Button {
                    showingImportPicker = true
                } label: {
                    HStack {
                        Label("Restore from Backup", systemImage: "square.and.arrow.down")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 12))
            .padding(.horizontal)

            Text("Export saves all your data as a JSON file. Restore replaces all current data with a backup.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private func exportData() {
        do {
            let data = try DataExporter.exportJSON(context: modelContext)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let filename = "FamFin-backup-\(dateFormatter.string(from: Date())).json"
            exportDocument = BackupDocument(data: data, filename: filename)
            showingExportPicker = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func performImport() {
        guard let url = importURL else { return }
        do {
            try DataExporter.importJSON(from: url, context: modelContext)
            importSuccess = true
        } catch {
            importError = error.localizedDescription
        }
        importURL = nil
    }
}

// MARK: - Currency Picker View

/// Full-screen currency list pushed via NavigationLink.
private struct CurrencyPickerView: View {
    @Binding var currencyCode: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(SupportedCurrency.allCases) { currency in
                Button {
                    currencyCode = currency.rawValue
                    dismiss()
                } label: {
                    HStack {
                        Text(currency.symbol)
                            .font(.body)
                            .frame(width: 32, alignment: .leading)

                        Text(currency.displayName)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        if currency.rawValue == currencyCode {
                            Image(systemName: "checkmark")
                                .font(.body)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .tint(.primary)
            }
        }
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Backup Document

/// A FileDocument wrapper for exporting JSON backup data.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data
    let filename: String

    init(data: Data, filename: String) {
        self.data = data
        self.filename = filename
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        filename = "FamFin-backup.json"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
