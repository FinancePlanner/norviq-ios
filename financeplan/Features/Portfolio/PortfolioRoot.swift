import SwiftUI
import Factory
import StockPlanShared

@MainActor
struct PortfolioRoot: View {
  @Environment(\.colorScheme) private var colorScheme
  @Binding var isSettingsPresented: Bool
  @Binding var pendingOpenSymbol: String?
  @Binding var pendingThesisWatchOpen: Bool
  @Binding var pendingAutomationDestination: AutomationNavigationDestination?
  @InjectedObservable(\Container.billingManager) private var billingManager
  @StateObject private var portfolioViewModel = PortfolioViewModel()

  var body: some View {
    NavigationStack {
      PortfolioScreen(
        pendingOpenSymbol: $pendingOpenSymbol,
        pendingThesisWatchOpen: $pendingThesisWatchOpen
      )
      .environmentObject(portfolioViewModel)
      .navigationDestination(item: $pendingAutomationDestination) { destination in
        switch destination {
        case let .smartScreen(id): ProGateView(billingManager: billingManager) { SmartScreeningScreen(
            initialScreenID: id
          ) }
        case let .rebalancing(id): ProGateView(billingManager: billingManager) { RebalancingRulesScreen(
            initialPortfolioID: id
          ) }
        }
      }
      .navigationTitle("Portfolio")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Settings", systemImage: "gearshape") {
            isSettingsPresented = true
          }
          .labelStyle(.iconOnly)
          .buttonStyle(.bordered)
          .tint(AppTheme.Colors.tint(for: colorScheme))
          .accessibilityLabel(LocalizedStringKey("Open settings"))
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
          NavigationLink(destination: PortfolioWorkspaceScreen()) {
            Label("Manage portfolios", systemImage: "rectangle.stack")
          }
          .labelStyle(.iconOnly)
          .accessibilityLabel("Manage portfolios")
          NavigationLink(destination: ProGateView(billingManager: billingManager) { ScenarioPlanningScreen() }) {
            Label("Scenario planning", systemImage: "chart.xyaxis.line")
          }
          .labelStyle(.iconOnly)
          .accessibilityLabel("Open scenario planning")
        }
        ToolbarItem(placement: .topBarTrailing) {
          Menu("Automation", systemImage: "wand.and.stars") {
            NavigationLink {
              ProGateView(billingManager: billingManager) { NetWorthForecastScreen() }
            } label: {
              Label("Net worth forecast", systemImage: "chart.xyaxis.line")
            }
            NavigationLink {
              ProGateView(billingManager: billingManager) { SmartScreeningScreen() }
            } label: {
              Label("Smart screens", systemImage: "line.3.horizontal.decrease.circle")
            }
            NavigationLink {
              ProGateView(billingManager: billingManager) { RebalancingRulesScreen() }
            } label: {
              Label("Rebalancing rules", systemImage: "scale.3d")
            }
            NavigationLink {
              NotificationInboxScreen()
            } label: {
              Label("Notifications", systemImage: "bell")
            }
          }
          .accessibilityLabel("Open wealth automation")
        }
      }
    }
  }
}
