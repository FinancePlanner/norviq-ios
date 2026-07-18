import Factory
import StockPlanShared
import SwiftUI

/// Read-only bank sync: connect a bank via Plaid, review synced transactions in
/// the suggestions inbox, and confirm the ones to record as expenses.
@MainActor
struct BankingView: View {
  @State private var viewModel = BankViewModel()
  @InjectedObservable(\Container.billingManager) private var billingManager

  @State private var isPresentingLink = false
  @State private var isPresentingGoCardless = false
  @State private var confirmingDisconnect: BankConnectionResponse?

  var body: some View {
    List {
      Section {
        ProGateView(billingManager: billingManager) {
          connectionsContent
        }
      } header: {
        Text("Banks")
      } footer: {
        Text("Norviq reads transactions only. It can never move money or make payments.")
      }

      if !viewModel.suggestions.isEmpty {
        Section("Review \(viewModel.suggestions.count) transaction\(viewModel.suggestions.count == 1 ? "" : "s")") {
          ForEach(viewModel.suggestions, id: \.id) { transaction in
            suggestionRow(transaction)
          }
        }
      }
    }
    .navigationTitle("Bank Sync")
    .navigationBarTitleDisplayMode(.inline)
    .task { await viewModel.load() }
    .refreshable { await viewModel.load() }
    .onChange(of: viewModel.pendingLinkToken) { _, token in
      isPresentingLink = token != nil
    }
    .sheet(isPresented: $isPresentingGoCardless) {
      GoCardlessConnectView(viewModel: viewModel)
    }
    .sheet(isPresented: $isPresentingLink, onDismiss: { viewModel.clearPendingLinkToken() }) {
      if let token = viewModel.pendingLinkToken {
        PlaidLinkView(
          linkToken: token,
          onSuccess: { publicToken, institutionId, institutionName in
            isPresentingLink = false
            Task { await viewModel.completeConnect(publicToken: publicToken, institutionId: institutionId, institutionName: institutionName) }
          },
          onExit: { isPresentingLink = false }
        )
        .ignoresSafeArea()
      }
    }
    .confirmationDialog(
      "Disconnect this bank?",
      isPresented: Binding(get: { confirmingDisconnect != nil }, set: { if !$0 { confirmingDisconnect = nil } }),
      titleVisibility: .visible
    ) {
      Button("Disconnect", role: .destructive) {
        if let connection = confirmingDisconnect {
          Task { await viewModel.disconnect(connection) }
        }
        confirmingDisconnect = nil
      }
      Button("Cancel", role: .cancel) { confirmingDisconnect = nil }
    } message: {
      Text("Synced transactions awaiting review are removed. Imported expenses are kept.")
    }
    .alert("Bank Sync", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
      Button("OK", role: .cancel) { viewModel.errorMessage = nil }
    } message: {
      Text(viewModel.errorMessage ?? "")
    }
  }

  @ViewBuilder
  private var connectionsContent: some View {
    if viewModel.isLoading, viewModel.connections.isEmpty {
      ProgressView("Loading…")
    }

    ForEach(viewModel.connections, id: \.id) { connection in
      connectionRow(connection)
    }

    Button {
      Task { await viewModel.beginConnect() }
    } label: {
      if viewModel.isConnecting {
        ProgressView()
      } else {
        Label("Connect a US bank", systemImage: "building.columns")
      }
    }
    .accessibilityIdentifier("banking.connect")

    Button {
      isPresentingGoCardless = true
    } label: {
      Label("Connect a European bank", systemImage: "building.columns.circle")
    }
    .accessibilityIdentifier("banking.connect.eu")
  }

  private func connectionRow(_ connection: BankConnectionResponse) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(connection.institutionName ?? "Bank")
          .font(.headline)
        Spacer()
        statusBadge(connection.status)
      }
      if let account = connection.accounts.first {
        Text(accountSummary(connection.accounts, first: account))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if let lastSynced = connection.lastSyncedAt {
        Text("Last synced \(lastSynced.formatted(.relative(presentation: .named)))")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      HStack(spacing: 16) {
        Button("Sync") { Task { await viewModel.sync(connection) } }
          .font(.caption.weight(.semibold))
        Button("Disconnect", role: .destructive) { confirmingDisconnect = connection }
          .font(.caption.weight(.semibold))
      }
      .padding(.top, 2)
    }
    .padding(.vertical, 4)
  }

  private func suggestionRow(_ transaction: BankTransactionResponse) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(transaction.merchant ?? transaction.descriptionText ?? "Transaction")
          .font(.subheadline.weight(.medium))
        Spacer()
        Text(amountText(transaction))
          .font(.subheadline.weight(.semibold))
          .monospacedDigit()
      }
      HStack(spacing: 6) {
        Text(transaction.date)
        if transaction.pending {
          Text("· Pending")
        }
        if transaction.possibleDuplicate {
          Text("· Possible duplicate")
            .foregroundStyle(.orange)
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      HStack {
        Menu {
          ForEach(BudgetPillar.allCases, id: \.self) { pillar in
            Button(pillarTitle(pillar)) {
              Task { await viewModel.importTransaction(transaction, pillar: pillar) }
            }
          }
        } label: {
          Label("Add as expense", systemImage: "plus.circle")
            .font(.caption.weight(.semibold))
        }
        .disabled(viewModel.busyTransactionIds.contains(transaction.id))

        Spacer()

        Button("Dismiss", role: .destructive) {
          Task { await viewModel.dismiss(transaction) }
        }
        .font(.caption.weight(.semibold))
        .disabled(viewModel.busyTransactionIds.contains(transaction.id))
      }
      .padding(.top, 2)
    }
    .padding(.vertical, 4)
  }

  private func statusBadge(_ status: BankConnectionStatus) -> some View {
    let (label, color): (String, Color) = switch status {
    case .active: ("Connected", .green)
    case .reauthRequired: ("Reconnect needed", .orange)
    case .disconnected: ("Disconnected", .secondary)
    case .error: ("Error", .red)
    }
    return Text(label)
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(color.opacity(0.15))
      .foregroundStyle(color)
      .clipShape(Capsule())
  }

  private func accountSummary(_ accounts: [BankAccountResponse], first: BankAccountResponse) -> String {
    let name = [first.name, first.mask.map { "••\($0)" }].compactMap { $0 }.joined(separator: " ")
    if accounts.count > 1 {
      return "\(name) + \(accounts.count - 1) more"
    }
    return name
  }

  private func amountText(_ transaction: BankTransactionResponse) -> String {
    let amount = abs(transaction.amount)
    let code = transaction.currency ?? "USD"
    return amount.formatted(.currency(code: code))
  }

  private func pillarTitle(_ pillar: BudgetPillar) -> String {
    switch pillar.rawValue {
    case "fundamentals": "Fundamentals"
    case "futureYou": "Future You"
    case "fun": "Fun"
    default: pillar.rawValue.capitalized
    }
  }
}
