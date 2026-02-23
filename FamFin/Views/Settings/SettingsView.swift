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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(SupportedCurrency.allCases) { currency in
                            Text(currency.displayName).tag(currency.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Currency")
                } footer: {
                    Text("Changing currency only affects how amounts are displayed. Existing values are not converted at an exchange rate.")
                }

                Section("Appearance") {
                    Picker("Appearance", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button("Export Data Backup", systemImage: "square.and.arrow.up") {
                        exportData()
                    }

                    Button("Restore from Backup", systemImage: "square.and.arrow.down") {
                        showingImportPicker = true
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Export saves all your data as a JSON file. Restore replaces all current data with a backup file.")
                }
            }
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
                    break // saved successfully
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
