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
  @State private var isPresentingCredentials = false
  @State private var tokenDraft = ""
  @State private var queryIdDraft = ""

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
        Text("Norviq reads your holdings only. It can never place trades or move funds. Each user connects their own IBKR Web Service token and query ID.")
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
    .sheet(isPresented: $isPresentingCredentials) {
      NavigationStack {
        Form {
          Section {
            SecureField("Token", text: $tokenDraft)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
            TextField("Query ID", text: $queryIdDraft)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
          } footer: {
            Text("Get these from IBKR after enabling the Norviq Web Service feed (Reporting → Third-party Reports).")
          }
        }
        .navigationTitle("Connect IBKR")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { isPresentingCredentials = false }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Connect") {
              Task { await connectWithCredentials() }
            }
            .disabled(tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || queryIdDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || viewModel.isConnectingBroker)
          }
        }
      }
      .presentationDetents([.medium])
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

    Text("Under development — IBKR statement sync is not live yet. Connect and Sync stay disabled until the feed is ready.")
      .font(.caption)
      .foregroundStyle(.orange)
      .accessibilityIdentifier("integrations.ibkr.underDevelopment")

    if let message = viewModel.brokerStatusMessage, !message.isEmpty {
      Text(message)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    if let error = viewModel.errorMessage, !error.isEmpty {
      Text(error)
        .font(.caption)
        .foregroundStyle(.red)
    }

    if viewModel.isIBKRConnected {
      Button {
        Task { await sync() }
      } label: {
        buttonLabel("Sync Now", isBusy: viewModel.isSyncingBroker)
      }
      .disabled(true)
      .accessibilityIdentifier("integrations.ibkr.sync")

      Button(role: .destructive) {
        isConfirmingDisconnect = true
      } label: {
        buttonLabel("Disconnect", isBusy: viewModel.isDisconnectingBroker)
      }
      .accessibilityIdentifier("integrations.ibkr.disconnect")
    } else {
      Button {
        tokenDraft = ""
        queryIdDraft = ""
        isPresentingCredentials = true
      } label: {
        buttonLabel("Connect IBKR", isBusy: viewModel.isConnectingBroker)
      }
      .disabled(true)
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
      return "Your IBKR positions sync from the daily statement feed."
    }
    return "Connect with your IBKR Web Service token and query ID."
  }

  private func connectWithCredentials() async {
    let didConnect = await viewModel.connectIBKRCredentials(
      token: tokenDraft,
      queryId: queryIdDraft
    )
    if didConnect {
      isPresentingCredentials = false
      PostHogSDK.shared.capture("broker_connected", properties: ["provider": "ibkr", "mode": "sod"])
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
