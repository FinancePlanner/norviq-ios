import Factory
import PostHog
import StockPlanShared
import SwiftUI

/// Dedicated home for read-only account connections, including bank sync and
/// IBKR brokerage sync.
@MainActor
struct IntegrationsView: View {
  @StateObject private var viewModel: CsvImportFlowViewModel
  @InjectedObservable(\Container.billingManager) private var billingManager

  @State private var isConfirmingDisconnect = false
  @State private var isPresentingCredentials = false
  @State private var tokenDraft = ""
  @State private var queryIdDraft = ""
  @State private var successCount = 0
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
        ProGateView(billingManager: billingManager) {
          ibkrCard
        }
      } header: {
        Text("Brokerage")
      } footer: {
        Text("Email [reportingintegration@interactivebrokers.com](mailto:reportingintegration@interactivebrokers.com) to enable the Norviq Web Service, then paste the token and query ID from IBKR Portal → Reporting → Third-party Reports. Sync reads the previous business day's statement and does not add those positions yet. Norviq cannot place trades or move money.")
      }
    }
    // Same canvas as the hub above and Bank Sync below; without it this screen
    // flashes the system grouped background between two themed ones.
    .vigilListChrome()
    .vigilScreenBackground()
    .appSensoryFeedback(success: successCount, destructive: destructiveCount)
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
            // The card that shows this error sits behind the sheet, so a failed
            // connect was silent here.
            if let error = viewModel.errorMessage, !error.isEmpty {
              Text(error)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.danger)
            }
          } footer: {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
              step(1, "From your IBKR account, email [reportingintegration@interactivebrokers.com](mailto:reportingintegration@interactivebrokers.com) and ask them to enable the Norviq Web Service feed.")
              step(2, "After IBKR enables it, open IBKR Portal → Reporting → Third-party Reports and copy the token and the query ID.")
              step(3, "Paste both here and tap Connect. Broker sync is part of Pro.")
              step(4, "Sync reads the previous business day's statement. It does not add those positions to your portfolio yet.")
            }
          }
        }
        .navigationTitle("Connect IBKR")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { isPresentingCredentials = false }
          }
          ToolbarItem(placement: .confirmationAction) {
            if viewModel.isConnectingBroker {
              ProgressView()
                .accessibilityLabel("Connecting")
            } else {
              Button("Connect") {
                Task { await connectWithCredentials() }
              }
              .disabled(tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || queryIdDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
          }
        }
      }
      .presentationDetents([.medium, .large])
      .interactiveDismissDisabled(viewModel.isConnectingBroker)
    }
  }

  @ViewBuilder
  private var ibkrCard: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("Interactive Brokers")
          .font(.headline)
        Spacer()
        // No verdict until the first load answers: "Not connected" during the
        // fetch is a claim the app cannot back yet.
        if !viewModel.isLoadingProviders || viewModel.ibkrConnection != nil {
          statusBadge
        }
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

    Text("Holdings import is coming soon. Your credentials are saved and Sync fetches your daily IBKR statement, but those holdings are not imported into your portfolio yet.")
      .font(.caption)
      .foregroundStyle(.secondary)
      .accessibilityIdentifier("integrations.ibkr.notice")

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

    if viewModel.isIBKRConnected {
      Button {
        Task { await sync() }
      } label: {
        buttonLabel("Sync Now", isBusy: viewModel.isSyncingBroker)
      }
      .disabled(viewModel.isSyncingBroker || viewModel.isDisconnectingBroker)
      .accessibilityIdentifier("integrations.ibkr.sync")

      Button(role: .destructive) {
        isConfirmingDisconnect = true
      } label: {
        buttonLabel("Disconnect", isBusy: viewModel.isDisconnectingBroker)
      }
      .disabled(viewModel.isSyncingBroker || viewModel.isDisconnectingBroker)
      .accessibilityIdentifier("integrations.ibkr.disconnect")
    } else {
      Button {
        tokenDraft = ""
        queryIdDraft = ""
        isPresentingCredentials = true
        viewModel.errorMessage = nil
      } label: {
        buttonLabel("Connect IBKR", isBusy: viewModel.isConnectingBroker)
      }
      .disabled(viewModel.isConnectingBroker)
      .accessibilityIdentifier("integrations.ibkr.connect")
    }
  }

  private var statusBadge: some View {
    let connected = viewModel.isIBKRConnected
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

  /// One numbered instruction. The number sits in its own column so wrapped
  /// lines hang under the text, not under the digit.
  private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.xs) {
      Text(verbatim: "\(number).")
        .monospacedDigit()
      Text(text)
    }
  }

  private var subtitle: String {
    if let detail = viewModel.ibkrConnection?.statusDetail, !detail.isEmpty {
      return detail
    }
    if viewModel.isIBKRConnected {
      return String(localized: "Your IBKR positions sync from the daily statement feed.")
    }
    return String(localized: "Connect with your IBKR Web Service token and query ID.")
  }

  private func connectWithCredentials() async {
    let didConnect = await viewModel.connectIBKRCredentials(
      token: tokenDraft,
      queryId: queryIdDraft
    )
    if didConnect {
      isPresentingCredentials = false
      successCount += 1
      PostHogSDK.shared.capture("broker_connected", properties: ["provider": "ibkr", "mode": "sod"])
    }
  }

  private func sync() async {
    let didSync = await viewModel.syncIBKRConnection()
    if didSync {
      successCount += 1
      PostHogSDK.shared.capture("broker_synced", properties: ["provider": "ibkr"])
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
