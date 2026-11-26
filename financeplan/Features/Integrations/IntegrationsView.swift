import Factory
import PostHog
import StockPlanShared
import SwiftUI

/// Dedicated home for read-only account connections: bank sync, and the IBKR
/// card, which now points at holdings import instead of a live feed.
@MainActor
struct IntegrationsView: View {
  @StateObject private var viewModel: CsvImportFlowViewModel

  @State private var isConfirmingDisconnect = false
  @State private var isPresentingBrokerImport = false
  @State private var destructiveCount = 0

  init(viewModel: CsvImportFlowViewModel = CsvImportFlowViewModel()) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    List {
      Section {
        NavigationLink {
          BankingView()
        } label: {
          Label("Bank Sync", systemImage: "building.columns")
        }
        .accessibilityIdentifier("integrations.bankSync")
      } header: {
        Text("Banks")
      } footer: {
        Text("Connect banks via Plaid or GoCardless, then review synced transactions before recording expenses.")
      }

      Section {
        ibkrCard
      } header: {
        Text("Brokerage")
      } footer: {
        Text("Norviq cannot place trades or move money.")
      }
    }
    // Same canvas as the hub above and Bank Sync below; without it this screen
    // flashes the system grouped background between two themed ones.
    .vigilListChrome()
    .vigilScreenBackground()
    .appSensoryFeedback(destructive: destructiveCount)
    // Named for the Settings row that leads here; the hub one level up already
    // owns "Integrations".
    .navigationTitle("Connected Accounts")
    .navigationBarTitleDisplayMode(.inline)
    .task { await viewModel.loadProvidersIfNeeded() }
    .refreshable { await viewModel.loadProviders(force: true) }
    .confirmationDialog(
      "Disconnect Interactive Brokers?",
      isPresented: $isConfirmingDisconnect,
      titleVisibility: .visible
    ) {
      Button("Disconnect and remove synced holdings", role: .destructive) {
        Task { await disconnect() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Positions imported from IBKR will be removed. Manually added holdings are kept.")
    }
    .sheet(isPresented: $isPresentingBrokerImport) {
      brokerImportDestination
    }
  }

  // MARK: - Broker import seam

  /// The ONE place the notice's "Import from broker" button is wired to.
  /// Today it presents the existing portfolio screenshot import; Task 11
  /// repoints it at the new "Import from broker" sheet by changing this view.
  @ViewBuilder
  private var brokerImportDestination: some View {
    PortfolioScreenshotImportSheet(portfolioListId: nil) {}
  }

  @ViewBuilder
  private var ibkrCard: some View {
    let notice = viewModel.ibkrNotice
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("Interactive Brokers")
          .font(.headline)
        Spacer()
        // No verdict until the first load answers: a status during the fetch
        // is a claim the app cannot back yet.
        if viewModel.ibkrConnection != nil {
          statusBadge
        }
      }
      if let lastSynced = viewModel.ibkrConnection?.lastSyncedAt {
        Text("Last synced \(lastSynced.formatted(.relative(presentation: .named)))")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)

    VStack(alignment: .leading, spacing: 6) {
      Text(notice.title)
        .font(.subheadline.weight(.semibold))
      Text(notice.body)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("integrations.ibkr.notice")

    Button {
      isPresentingBrokerImport = true
    } label: {
      Text(notice.buttonTitle)
    }
    .accessibilityIdentifier("integrations.ibkr.importFromBroker")

    if let message = viewModel.brokerStatusMessage, !message.isEmpty {
      Text(message)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    if let error = viewModel.errorMessage, !error.isEmpty {
      Text(error)
        .font(.caption)
        .foregroundStyle(AppTheme.Colors.danger)
    }

    // Disconnect stays only for a connection with something live to remove.
    if viewModel.canDisconnectIBKR {
      Button(role: .destructive) {
        isConfirmingDisconnect = true
      } label: {
        buttonLabel("Disconnect", isBusy: viewModel.isDisconnectingBroker)
      }
      .disabled(viewModel.isDisconnectingBroker)
      .accessibilityIdentifier("integrations.ibkr.disconnect")
    }
  }

  private var statusBadge: some View {
    let connected = viewModel.canDisconnectIBKR
    // Two Text literals, not a ternary of strings: the ternary infers String
    // and skips the String Catalog.
    return (connected ? Text("Connected") : Text("Not connected"))
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, AppTheme.Spacing.sm)
      .padding(.vertical, AppTheme.Spacing.xs)
      // Status, not money: `success`, on the 12% chip the brand doc measured.
      .background(connected ? AppTheme.Colors.success.opacity(0.12) : Color.secondary.opacity(0.12))
      .foregroundStyle(connected ? AppTheme.Colors.success : Color.secondary)
      .clipShape(Capsule())
  }

  @ViewBuilder
  private func buttonLabel(_ title: LocalizedStringKey, isBusy: Bool) -> some View {
    // Keep the title while busy so the row does not jump and VoiceOver still
    // reads the action; same shape as GoCardlessConnectView.
    HStack {
      Text(title)
      Spacer()
      if isBusy {
        ProgressView()
      }
    }
  }

  private func disconnect() async {
    let didDisconnect = await viewModel.disconnectIBKRConnection()
    if didDisconnect {
      destructiveCount += 1
      PostHogSDK.shared.capture("broker_disconnected", properties: ["provider": "ibkr"])
    }
  }
}
