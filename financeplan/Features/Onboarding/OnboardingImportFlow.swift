//
//  OnboardingImportFlow.swift
//  financeplan
//
//  Created by Fernando Correia on 27.02.26.
//
import SwiftUI
import UniformTypeIdentifiers

struct OnboardingImportFlow: View {
    enum Step: Hashable {
        case chooseMethod
        case csv
        case manual
        case api
        case done
    }
    
    @State private var step: Step = .chooseMethod
    let onFinished: () -> Void
    
    var body: some View {
        Group {
            switch step {
            case .chooseMethod:
                InitialStockImportScreen { method in handleSelection(method) }
            case .csv:
                CSVImportScreen(
                    onBack: { step = .chooseMethod },
                    onDone: { _ in step = .done }
                )
            case .manual:
                ManualImportScreen(
                    onBack: { step = .chooseMethod },
                    onDone: { _ in step = .done }
                )
            case .api:
                APIKeyImportScreen(
                    onBack: { step = .chooseMethod },
                    onDone: { step = .done }
                )
            case .done:
                Color.clear.onAppear(perform: onFinished)
                }
            }
            
        
    }
    
    private func handleSelection(_ method: StockImportMethod) {
        switch method {
            case .csv:
            step = .csv
        case .manual:
            step = .manual
        case .api:
            step = .api
        }
    }
}

// API KEY VIEW
struct APIKeyImportScreen: View {
    @Environment(\.colorScheme) private var colorScheme

    let onBack: () -> Void
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Connect API")
                    .font(.title2).bold()

                Text("You can add API key support here later.")
                    .foregroundStyle(.secondary)

                Spacer()

                HStack {
                    Button("Back") { onBack() }
                    Spacer()
                    Button("Finish") { onDone() }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.Colors.tint(for: colorScheme))
                }
            }
            .padding(16)
            .navigationTitle("API Import")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MANUAL ENTRY

struct ManualEntry: Identifiable, Equatable {
    let id = UUID()
    var symbol: String = ""
    var quantity: String = ""
    var price: String = ""
}

struct ManualImportScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var entries: [ManualEntry] = [ManualEntry()]
    
    let onBack: () -> Void
    let onDone: ([ImportedPosition]) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                List {
                    ForEach($entries) { $entry in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Symbol (e.g., AAPL)", text: $entry.symbol)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled(true)

                            HStack {
                                TextField("Quantity", text: $entry.quantity)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.decimalPad)
                                    .frame(maxWidth: .infinity, alignment: .init(horizontal: .leading, vertical: .center))

                                TextField("Price", text: $entry.price)
                                    .keyboardType(.decimalPad)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indices in
                        entries.remove(atOffsets: indices)
                    }
                }
            }
            .listStyle(.plain)
            
            HStack {
                Button {
                    entries.append(ManualEntry())
                } label: {
                    Label("Add row", systemImage: "plus.circle.fill")
                }
                
                Spacer()
                
                Button("Continue") {
                                        let positions = entries
                                            .compactMap { entry -> ImportedPosition? in
                                                let symbol = entry.symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                                                guard !symbol.isEmpty else { return nil }
                                                let qty = Double(entry.quantity.replacingOccurrences(of: ",", with: "")) ?? 0
                                                let price = Double(entry.price.replacingOccurrences(of: ",", with: "")) ?? 0
                                                guard qty > 0 else { return nil }
                                                return ImportedPosition(symbol: symbol, quantity: qty, price: price)
                                            }
                                        onDone(positions)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(AppTheme.Colors.tint(for: colorScheme))
                                    .disabled(entries.allSatisfy { $0.symbol.isEmpty })
            }
        }
        .padding(16)
        .navigationTitle("Manual Import")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") {
                    onBack()
                }
            }
        }
    }
}


// CSV View
struct ImportedPosition: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
    let quantity: Double
    let price: Double
}

struct CSVImportScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isImporterPresented = false
    @State private var previewRows: [ImportedPosition] = []
    @State private var errorMessage: String?

    let onBack: () -> Void
    let onDone: ([ImportedPosition]) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Import from CSV")
                    .font(.title2).bold()

                Button {
                    isImporterPresented = true
                } label: {
                    Label("Select CSV File", systemImage: "tray.and.arrow.down.fill")
                        .font(.headline).bold()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.tint(for: colorScheme))

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                if !previewRows.isEmpty {
                    List(previewRows) { row in
                        HStack {
                            Text(row.symbol).bold()
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Qty: \(Int(row.quantity))")
                                Text("Price: \(row.price.currency)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                } else {
                    Text("No preview yet. Pick a CSV to see a preview.")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }

                Spacer()

                HStack {
                    Button("Back") { onBack() }
                    Spacer()
                    Button("Continue") {
                        onDone(previewRows)
                    }
                    .disabled(previewRows.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.tint(for: colorScheme))
                }
            }
            .padding(16)
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [UTType.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                do {
                    let urls = try result.get()
                    guard let url = urls.first else { return }
                    let data = try Data(contentsOf: url)
                    guard let text = String(data: data, encoding: .utf8) else {
                        throw CocoaError(.fileReadInapplicableStringEncoding)
                    }
                    previewRows = parseCSV(text)
                    errorMessage = nil
                } catch {
                    errorMessage = "Failed to read CSV: \(error.localizedDescription)"
                    previewRows = []
                }
            }
            .navigationTitle("CSV Import")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func parseCSV(_ text: String) -> [ImportedPosition] {
        // Very simple parser: expects header with symbol,quantity,price
        var rows: [ImportedPosition] = []
        let lines = text.split(whereSeparator: \.isNewline)
        guard !lines.isEmpty else { return [] }

        // Skip header if present (contains non-numeric)
        let startIndex = lines.first?.contains(",") == true ? 1 : 0

        for line in lines.dropFirst(startIndex) {
            let parts = line.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 3 else { continue }
            let symbol = parts[0].uppercased()
            let qty = Double(parts[1]) ?? 0
            let price = Double(parts[2]) ?? 0
            guard !symbol.isEmpty, qty > 0 else { continue }
            rows.append(ImportedPosition(symbol: symbol, quantity: qty, price: price))
        }
        return rows
    }
}
