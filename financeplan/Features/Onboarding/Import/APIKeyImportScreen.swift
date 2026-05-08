//
//  APIKeyImportScreen.swift
//  financeplan
//
import Combine
import Factory
import StockPlanShared
import SwiftUI

struct APIKeyImportScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var viewModel = BrokerAPIImportViewModel()
  var headerNamespace: Namespace.ID?

  let onBack: () -> Void
  let onDone: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      // Custom nav bar
      OnboardingNavBar(
        title: "API Import",
        icon: "link.circle.fill",
        namespace: headerNamespace,
        onBack: onBack
      )

      ScrollView {
        VStack(spacing: 24) {
          if viewModel.isLoading {
            ProgressView("Loading broker connections...")
              .padding(.top, 30)
          } else {
            GlassCard(cornerRadius: 22) {
              VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                  Image(systemName: "building.columns.fill")
                    .foregroundStyle(.indigo)
                  Text("Interactive Brokers")
                    .typography(.label, weight: .semibold)
                  Spacer()
                  Text(viewModel.ibkrStatusTitle)
                    .typography(.caption, weight: .semibold)
                    .foregroundStyle(viewModel.ibkrStatusColor)
                }

                Text(viewModel.ibkrStatusSubtitle)
                  .typography(.small)
                  .foregroundStyle(.secondary)
                  .frame(maxWidth: .infinity, alignment: .leading)

                if let syncMessage = viewModel.syncMessage {
                  Text(syncMessage)
                    .typography(.small)
                    .foregroundStyle(AppTheme.Colors.success)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let errorMessage = viewModel.errorMessage {
                  Text(errorMessage)
                    .typography(.small)
                    .foregroundStyle(AppTheme.Colors.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
              }
            }
            .padding(.top, 20)

            Button {
              Task { await viewModel.syncIBKRNow() }
            } label: {
              HStack(spacing: 8) {
                if viewModel.isSyncing {
                  ProgressView()
                } else {
                  Image(systemName: "arrow.triangle.2.circlepath")
                }
                Text(viewModel.isSyncing ? "Syncing..." : "Sync IBKR Now")
                  .font(.headline)
                  .fontWeight(.bold)
              }
            }
            .buttonStyle(GlowingButtonStyle())
            .padding(.horizontal, 24)
            .disabled(viewModel.isSyncing)

            Button {
              Task { await viewModel.load(force: true) }
            } label: {
              Text("Refresh Connection State")
                .typography(.small, weight: .semibold)
                .foregroundStyle(.secondary)
            }
          }

          Button {
            onDone()
          } label: {
            Text("Continue")
              .font(.headline)
              .fontWeight(.bold)
          }
          .buttonStyle(GlowingButtonStyle())
          .padding(.horizontal, 24)
        }
        .padding(.vertical, 20)
      }
    }
    .background(MeshGradientBackground().ignoresSafeArea())
    .task {
      await viewModel.loadIfNeeded()
    }
  }
}

@MainActor
private final class BrokerAPIImportViewModel: ObservableObject {
  @Published private(set) var connections: [BrokerConnectionResponse] = []
  @Published private(set) var isLoading = false
  @Published private(set) var isSyncing = false
  @Published var errorMessage: String?
  @Published var syncMessage: String?

  private let brokerService: any BrokerServicing
  private var hasLoaded = false

  init(brokerService: any BrokerServicing = Container.shared.brokerService()) {
    self.brokerService = brokerService
  }

  var ibkrConnection: BrokerConnectionResponse? {
    connections.first { $0.provider.lowercased() == "ibkr" }
  }

  var ibkrStatusTitle: String {
    if let connection = ibkrConnection {
      return connection.status.uppercased()
    }
    return "NOT CONNECTED"
  }

  var ibkrStatusSubtitle: String {
    if let connection = ibkrConnection {
      return "Provider: \(connection.provider.uppercased()) • Status: \(connection.status)"
    }
    return "No broker connection yet. Trigger a sync run to start importing positions."
  }

  var ibkrStatusColor: Color {
    guard let status = ibkrConnection?.status.lowercased() else { return .secondary }
    if status == "active" || status == "connected" || status == "csv" {
      return AppTheme.Colors.success
    }
    if status == "error" || status == "failed" {
      return AppTheme.Colors.danger
    }
    return .orange
  }

  func loadIfNeeded() async {
    guard !hasLoaded else { return }
    await load(force: true)
  }

  func load(force: Bool = false) async {
    if isLoading { return }
    if !force, hasLoaded { return }

    isLoading = true
    errorMessage = nil
    defer {
      isLoading = false
      hasLoaded = true
    }

    do {
      connections = try await brokerService.listConnections()
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
  }

  func syncIBKRNow() async {
    guard !isSyncing else { return }
    isSyncing = true
    errorMessage = nil
    defer { isSyncing = false }

    do {
      let response = try await brokerService.syncIBKR()
      syncMessage = "Sync requested: \(response.status) (\(response.runId.prefix(8)))"
      await load(force: true)
    } catch {
      syncMessage = nil
      errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
  }
}
