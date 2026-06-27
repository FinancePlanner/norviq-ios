import Combine
import PostHog
import StockPlanShared
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct PortfolioCSVImportSheet: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var viewModel: CsvImportFlowViewModel
  @State private var isImporterPresented = false

  let onImportCompleted: @MainActor () async -> Void

  init(
    portfolioListId: String?,
    onImportCompleted: @escaping @MainActor () async -> Void
  ) {
    _viewModel = StateObject(wrappedValue: CsvImportFlowViewModel(portfolioListId: portfolioListId))
    self.onImportCompleted = onImportCompleted
  }

  var body: some View {
    NavigationStack {
      List {
        brokerSection

        csvProviderSection

        Section {
          CSVImportFormatHint()
        }

        Section("CSV File") {
          Button {
            isImporterPresented = true
          } label: {
            Text(viewModel.selectedFileName ?? "Select CSV File")
          }
          .accessibilityIdentifier("portfolioCSVImport.selectFile")

          if let selectedFileName = viewModel.selectedFileName {
            Text(selectedFileName)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }

          if viewModel.isPreviewing {
            ProgressView("Parsing CSV preview...")
          }
        }

        if let preview = viewModel.previewResponse {
          Section("Preview") {
            Text("\(preview.items.count) parsed row(s) • \(preview.errors.count) issue(s)")
              .foregroundStyle(.secondary)

            ForEach(preview.items, id: \.line) { item in
              VStack(alignment: .leading, spacing: 4) {
                Text(item.symbol)
                  .font(.headline)
                Text("Line \(item.line)")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Text("Shares: \(item.shares?.formatted(.number.precision(.fractionLength(0...6))) ?? "-") • Buy price: \(item.buyPrice?.formatted(.number.precision(.fractionLength(0...6))) ?? "-")")
                  .font(.headline)
              }
            }
          }
        }

        if let preview = viewModel.previewResponse, !preview.errors.isEmpty {
          Section("Preview Errors") {
            ForEach(preview.errors, id: \.line) { error in
              VStack(alignment: .leading, spacing: 4) {
                Text("Line \(error.line)")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Text(error.message)
                  .font(.subheadline)
              }
            }
          }
        }

        if let result = viewModel.commitResponse {
          Section("Import Result") {
            Text("Inserted: \(result.inserted.count) • Updated: \(result.updated.count) • Errors: \(result.errors.count)")

            if !result.errors.isEmpty {
              ForEach(result.errors, id: \.line) { error in
                VStack(alignment: .leading, spacing: 4) {
                  Text("Line \(error.line)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  Text(error.message)
                    .font(.subheadline)
                }
              }
            }
          }
        }

        if let statusMessage = viewModel.brokerStatusMessage {
          Section("Broker Status") {
            Text(statusMessage)
              .foregroundStyle(.secondary)
          }
        }

        if let errorMessage = viewModel.errorMessage {
          Section {
            Text(errorMessage)
              .foregroundStyle(.red)
          }
        }
      }
      .navigationTitle("Import CSV")
      .accessibilityIdentifier("portfolioCSVImportSheet")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            dismiss()
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button {
            Task {
              let didImport = await viewModel.commitImport()
              if didImport {
                // PostHog: Track successful CSV import
                let insertedCount = viewModel.commitResponse?.inserted.count ?? 0
                let updatedCount = viewModel.commitResponse?.updated.count ?? 0
                PostHogSDK.shared.capture("portfolio_csv_imported", properties: [
                  "inserted_count": insertedCount,
                  "updated_count": updatedCount,
                ])
                await onImportCompleted()
              }
            }
          } label: {
            if viewModel.isImporting {
              ProgressView()
            } else {
              Text("Import")
            }
          }
          .disabled(!viewModel.canImport)
          .accessibilityIdentifier("portfolioCSVImport.commit")
        }
      }
      .fileImporter(
        isPresented: $isImporterPresented,
        allowedContentTypes: [UTType.commaSeparatedText, .plainText],
        allowsMultipleSelection: false
      ) { result in
        do {
          let urls = try result.get()
          guard let url = urls.first else { return }
          Task {
            await viewModel.loadCSV(from: url)
          }
        } catch {
          viewModel.errorMessage = "Failed to read CSV: \(error.localizedDescription)"
        }
      }
      .task {
        await prepareSheet()
      }
      .onChange(of: viewModel.selectedProvider) { _, _ in
        refreshPreviewIfNeeded()
      }
    }
  }

  private var brokerSection: some View {
    Section("IBKR Broker") {
      VStack(alignment: .leading, spacing: 6) {
        Text("Interactive Brokers")
          .font(.headline)
        Text(brokerSubtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      if viewModel.isLoadingProviders {
        ProgressView("Loading broker connection...")
      }

      if viewModel.isIBKRConnected {
        Button {
          Task {
            let didSync = await viewModel.syncIBKRConnection()
            if didSync {
              // PostHog: Track IBKR broker sync
              PostHogSDK.shared.capture("broker_synced", properties: [
                "provider": "ibkr",
              ])
              await onImportCompleted()
            }
          }
        } label: {
          if viewModel.isSyncingBroker {
            ProgressView()
          } else {
            Text("Sync Now")
          }
        }
        .accessibilityIdentifier("portfolioBroker.sync")

        Button(role: .destructive) {
          Task {
            let result = await viewModel.disconnectIBKRConnection()
            if result {
              // PostHog: Track IBKR broker disconnect
              PostHogSDK.shared.capture("broker_disconnected", properties: [
                "provider": "ibkr",
              ])
            }
          }
        } label: {
          if viewModel.isDisconnectingBroker {
            ProgressView()
          } else {
            Text("Disconnect")
          }
        }
        .accessibilityIdentifier("portfolioBroker.disconnect")
      } else {
        Button {
          Task {
            let didConnect = await viewModel.connectIBKR()
            if didConnect {
              // PostHog: Track IBKR broker connection
              PostHogSDK.shared.capture("broker_connected", properties: [
                "provider": "ibkr",
              ])
              await onImportCompleted()
            }
          }
        } label: {
          if viewModel.isConnectingBroker {
            ProgressView()
          } else {
            Text("Connect IBKR")
          }
        }
        .accessibilityIdentifier("portfolioBroker.connect")
      }
    }
  }

  private var csvProviderSection: some View {
    Section("CSV Provider") {
      Picker("Provider", selection: $viewModel.selectedProvider) {
        ForEach(viewModel.availableProviders, id: \.self) { provider in
          Text(provider.uppercased()).tag(provider)
        }
      }
      .pickerStyle(.menu)
      .disabled(viewModel.isLoadingProviders)
    }
  }

  private var brokerSubtitle: String {
    if let connection = viewModel.ibkrConnection {
      return "Status: \(connection.status.capitalized)"
    }
    return "Connect IBKR to auto-import positions into Portfolio."
  }

  private func prepareSheet() async {
    await viewModel.loadProvidersIfNeeded()
  }

  private func refreshPreviewIfNeeded() {
    guard viewModel.previewResponse != nil else { return }
    Task {
      await viewModel.previewCSV()
    }
  }
}
