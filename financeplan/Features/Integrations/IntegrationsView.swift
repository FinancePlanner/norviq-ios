import Factory
import PostHog
import StockPlanShared
import SwiftUI

/// Dedicated home for read-only account connections. Currently surfaces the
/// IBKR brokerage sync (previously buried in the portfolio CSV-import sheet);
/// bank connections join this screen in a later phase.
@MainActor
struct IntegrationsView: View {
  @StateObject private var viewModel: CsvImportFlowViewModel
  @InjectedObservable(\Container.billingManager) private var billingManager

  @State private var isConfirmingDisconnect = false

  init(viewModel: CsvImportFlowViewModel = CsvImportFlowViewModel()) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    List {
      Section {
        ProGateView(billingManager: billingManager) {
          ibkrCard
        }
      } header: {
        Text("Connected accounts")
      } footer: {
        Text("Norviq reads your holdings only. It can never place trades or move funds.")
      }

      Section {
        NavigationLink {
          BankingView()
        } label: {
          Label("Bank Sync", systemImage: "building.columns")
        }
        .accessibilityIdentifier("integrations.bankSync")
      } footer: {
        Text("Connect a bank to review transactions and turn them into expenses.")
      }
    }
    .navigationTitle("Integrations")
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
  }

  @ViewBuilder
  private var ibkrCard: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("Interactive Brokers")
          .font(.headline)
        Spacer()
        statusBadge
      }
      Text(subtitle)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      if let lastSynced = viewModel.ibkrConnection?.lastSyncedAt {
        Text("Last synced \(lastSynced.formatted(.relative(presentation: .named)))")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)

    if viewModel.isLoadingProviders {
      ProgressView("Loading connection…")
    }

    if let message = viewModel.brokerStatusMessage, !message.isEmpty {
      Text(message)
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    if viewModel.isIBKRConnected {
      Button {
        Task { await sync() }
      } label: {
        buttonLabel("Sync Now", isBusy: viewModel.isSyncingBroker)
      }
      .accessibilityIdentifier("integrations.ibkr.sync")

      Button(role: .destructive) {
        isConfirmingDisconnect = true
      } label: {
        buttonLabel("Disconnect", isBusy: viewModel.isDisconnectingBroker)
      }
      .accessibilityIdentifier("integrations.ibkr.disconnect")
    } else {
      Button {
        Task { await connect() }
      } label: {
        buttonLabel("Connect IBKR", isBusy: viewModel.isConnectingBroker)
      }
      .accessibilityIdentifier("integrations.ibkr.connect")
    }
  }

  private var statusBadge: some View {
    let connected = viewModel.isIBKRConnected
    return Text(connected ? "Connected" : "Not connected")
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(connected ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15))
      .foregroundStyle(connected ? Color.green : Color.secondary)
      .clipShape(Capsule())
  }

  @ViewBuilder
  private func buttonLabel(_ title: String, isBusy: Bool) -> some View {
    if isBusy {
      ProgressView()
    } else {
      Text(title)
    }
  }

  private var subtitle: String {
    if let detail = viewModel.ibkrConnection?.statusDetail, !detail.isEmpty {
      return detail
    }
    if viewModel.isIBKRConnected {
      return "Your IBKR positions sync automatically each day."
    }
    return "Connect IBKR to auto-import positions into your portfolio."
  }

  private func connect() async {
    let didConnect = await viewModel.connectIBKR()
    if didConnect {
      PostHogSDK.shared.capture("broker_connected", properties: ["provider": "ibkr"])
    }
  }

  private func sync() async {
    let didSync = await viewModel.syncIBKRConnection()
    if didSync {
      PostHogSDK.shared.capture("broker_synced", properties: ["provider": "ibkr"])
    }
  }

  private func disconnect() async {
    let didDisconnect = await viewModel.disconnectIBKRConnection()
    if didDisconnect {
      PostHogSDK.shared.capture("broker_disconnected", properties: ["provider": "ibkr"])
    }
  }
}
