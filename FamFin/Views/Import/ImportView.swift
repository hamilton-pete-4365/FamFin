import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Entry point for the bank import flow.
/// Checks premium access, lets the user pick a CSV or OFX file,
/// then routes to the appropriate mapping/review screen.
struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumManager.self) private var premiumManager

    @State private var showingFilePicker = false
    @State private var showingPaywall = false
    @State private var errorMessage: String?

    // Navigation destinations after file parsing
    @State private var csvData: Data?
    @State private var csvRows: [[String]] = []
    @State private var showCSVMapping = false

    @State private var ofxTransactions: [ImportedTransaction] = []
    @State private var showOFXReview = false

    @State private var importCompleteCount: Int?

    var body: some View {
        NavigationStack {
            ImportContentView(
                hasPremiumAccess: premiumManager.hasPremiumAccess,
                onSelectFile: { showingFilePicker = true },
                onShowPaywall: { showingPaywall = true }
            )
            .navigationTitle("Bank Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: importableTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .navigationDestination(isPresented: $showCSVMapping) {
                CSVColumnMappingView(
                    rawData: csvData ?? Data(),
                    rows: csvRows,
                    onImportComplete: handleImportComplete
                )
            }
            .navigationDestination(isPresented: $showOFXReview) {
                ImportReviewView(
                    transactions: ofxTransactions,
                    onImportComplete: handleImportComplete
                )
            }
            .alert("Import Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Import Complete", isPresented: Binding(
                get: { importCompleteCount != nil },
                set: { if !$0 { importCompleteCount = nil } }
            )) {
                Button("Done") {
                    importCompleteCount = nil
                    dismiss()
                }
            } message: {
                if let count = importCompleteCount {
                    Text("\(count) transaction\(count == 1 ? "" : "s") imported successfully.")
                }
            }
        }
    }

    /// The UTTypes accepted by the file picker.
    private var importableTypes: [UTType] {
        var types: [UTType] = [.commaSeparatedText]
        if let ofx = UTType(filenameExtension: "ofx") {
            types.append(ofx)
        }
        if let qfx = UTType(filenameExtension: "qfx") {
            types.append(qfx)
        }
        return types
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            processFile(at: url)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func processFile(at url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let ext = url.pathExtension.lowercased()

            if ext == "ofx" || ext == "qfx" {
                var transactions = try OFXParser.parse(data: data)
                transactions = AutoCategorizer.categorize(transactions, context: modelContext)
                transactions = AutoCategorizer.detectDuplicates(transactions, context: modelContext)
                ofxTransactions = transactions
                showOFXReview = true
            } else {
                // CSV
                let rows = CSVParser.parseRawRows(from: data)
                guard !rows.isEmpty else {
                    errorMessage = "The CSV file appears to be empty."
                    return
                }
                csvData = data
                csvRows = rows
                showCSVMapping = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleImportComplete(_ count: Int) {
        importCompleteCount = count
    }
}

// MARK: - Content view

/// The main content area of the import screen, separated into its own View struct.
private struct ImportContentView: View {
    let hasPremiumAccess: Bool
    let onSelectFile: () -> Void
    let onShowPaywall: () -> Void

    var body: some View {
        if hasPremiumAccess {
            ImportReadyView(onSelectFile: onSelectFile)
        } else {
            ImportLockedView(onShowPaywall: onShowPaywall)
        }
    }
}

// MARK: - Premium unlocked state

/// Shown when the user has premium access -- prompts them to select a file.
private struct ImportReadyView: View {
    let onSelectFile: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Import Transactions", systemImage: "doc.text.fill")
        } description: {
            Text("Import transactions from your bank statement. Supports CSV and OFX/QFX file formats.")
        } actions: {
            Button("Select File", systemImage: "folder", action: onSelectFile)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}

// MARK: - Premium locked state

/// Shown when the user does not have premium access.
private struct ImportLockedView: View {
    let onShowPaywall: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Premium Feature", systemImage: "crown.fill")
        } description: {
            Text("Bank import is available with a FamFin Premium subscription. Import CSV and OFX files from your bank to quickly add transactions.")
        } actions: {
            Button("View Plans", systemImage: "star.circle.fill", action: onShowPaywall)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}
