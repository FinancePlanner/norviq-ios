//
//  OnboardingImportFlow.swift
//  financeplan
//
//  Created by Fernando Correia on 27.02.26.
//
import SwiftUI
import UniformTypeIdentifiers

struct OnboardingImportFlow: View {
    @StateObject private var viewModel = OnboardingImportViewModel()
    @Namespace private var headerNS
    let onFinished: () -> Void
    
    var body: some View {
        Group {
            switch viewModel.step {
            case .chooseMethod:
                InitialStockImportScreen(onImportCompleted: { method in viewModel.select(method) }, headerNamespace: headerNS)
            case .csv:
                CSVImportScreen(headerNamespace: headerNS,
                    onBack: { viewModel.backToChoose() },
                    onDone: { _ in viewModel.finish() }
                )
            case .manual:
                ManualImportScreen(headerNamespace: headerNS,
                    onBack: { viewModel.backToChoose() },
                    onDone: { _ in viewModel.finish() }
                )
            case .api:
                APIKeyImportScreen(headerNamespace: headerNS,
                    onBack: { viewModel.backToChoose() },
                    onDone: { viewModel.finish() }
                )
            case .done:
                Color.clear.onAppear(perform: onFinished)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.step)
    }
}

// API KEY VIEW
struct APIKeyImportScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    var headerNamespace: Namespace.ID? = nil

    let onBack: () -> Void
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
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
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AppTheme.Colors.navBarBackground(for: colorScheme), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .imageScale(.medium)
                            .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                            .modifier(MatchedGeometryIfAvailable(id: "onboarding.header.icon", namespace: headerNamespace))
                        Text("API Import")
                            .font(.headline)
                            .modifier(MatchedGeometryIfAvailable(id: "onboarding.header.title", namespace: headerNamespace))
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { onBack() }
                }
            }
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
    @StateObject private var viewModel = ManualImportViewModel()
    var headerNamespace: Namespace.ID? = nil
    
    let onBack: () -> Void
    let onDone: ([ImportedPosition]) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                List {
                    ForEach($viewModel.entries) { $entry in
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
                        viewModel.removeRows(at: indices)
                    }
                }
            }
            .listStyle(.plain)
            
            HStack {
                Button {
                    viewModel.addRow()
                } label: {
                    Label("Add row", systemImage: "plus.circle.fill")
                }
                
                Spacer()
                
                Button("Continue") {
                    onDone(viewModel.buildPositions())
                }
                Button("Continue") {
                  let positions = viewModel.buildPositions()
                  Task {
                    do {
                      // For each position, fire CreateStockEndpoint
                      for pos in positions {
                        let endpoint = CreateStockEndpoint(
                          symbol: pos.symbol,
                          shares: Int(pos.quantity),   // Or change endpoint to Double if needed
                          buyPrice: pos.price,
                          buyDate: dateFormatter.string(from: Date()), // Or collect per-row
                          notes: "" // Or collect per-row
                        )
                        // Execute via your HTTP client (like AuthHTTPClient style)
                        // let response: StockResponse = try await apiClient.call(endpoint)
                      }
                      onDone(positions)
                    } catch {
                      // Show error feedback
                    }
                  }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.tint(for: colorScheme))
                .disabled(viewModel.entries.allSatisfy { $0.symbol.isEmpty })
            }
        }
        .padding(16)
        .navigationTitle("Manual Import")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.Colors.navBarBackground(for: colorScheme), for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .imageScale(.medium)
                        .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                        .modifier(MatchedGeometryIfAvailable(id: "onboarding.header.icon", namespace: headerNamespace))
                    Text("Manual Import")
                        .font(.headline)
                        .modifier(MatchedGeometryIfAvailable(id: "onboarding.header.title", namespace: headerNamespace))
                }
            }
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
    @StateObject private var viewModel = CSVImportViewModel()
    var headerNamespace: Namespace.ID? = nil

    let onBack: () -> Void
    let onDone: ([ImportedPosition]) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Button {
                    isImporterPresented = true
                } label: {
                    Label("Select CSV File", systemImage: "tray.and.arrow.down.fill")
                        .font(.headline).bold()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.tint(for: colorScheme))

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                if !viewModel.previewRows.isEmpty {
                    List(viewModel.previewRows) { row in
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
                        onDone(viewModel.previewRows)
                    }
                    .disabled(viewModel.previewRows.isEmpty)
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
                    viewModel.loadCSV(from: url)
                } catch {
                    viewModel.errorMessage = "Failed to read CSV: \(error.localizedDescription)"
                    viewModel.previewRows = []
                }
            }
            .navigationTitle("CSV Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AppTheme.Colors.navBarBackground(for: colorScheme), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .imageScale(.medium)
                            .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                            .modifier(MatchedGeometryIfAvailable(id: "onboarding.header.icon", namespace: headerNamespace))
                        Text("CSV Import")
                            .font(.headline)
                            .modifier(MatchedGeometryIfAvailable(id: "onboarding.header.title", namespace: headerNamespace))
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { onBack() }
                }
            }
        }
    }
}

private struct MatchedGeometryIfAvailable: ViewModifier {
  let id: String
  let namespace: Namespace.ID?
  func body(content: Content) -> some View {
    if let ns = namespace {
      content.matchedGeometryEffect(id: id, in: ns)
    } else {
      content
    }
  }
}
