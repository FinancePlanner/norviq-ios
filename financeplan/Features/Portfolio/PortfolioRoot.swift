import SwiftUI
import Factory
import StockPlanShared

/// Toolbar destinations reached from the portfolio root. Value-based links
/// keep the destination screens (ScenarioPlanningScreen is ~850 lines) from
/// being constructed on every PortfolioRoot body pass.
enum PortfolioRootRoute: Hashable {
  case workspace
  case scenarioPlanning
  case netWorthForecast
  case smartScreens
  case rebalancingRules
  case notifications
}

@MainActor
struct PortfolioRoot: View {
  @Environment(\.colorScheme) private var colorScheme
  @Binding var isSettingsPresented: Bool
  @Binding var pendingOpenSymbol: String?
  @Binding var pendingThesisWatchOpen: Bool
  @Binding var pendingAutomationDestination: AutomationNavigationDestination?
  @InjectedObservable(\Container.billingManager) private var billingManager
  @State private var portfolioViewModel = PortfolioViewModel()

  var body: some View {
    NavigationStack {
      PortfolioScreen(
        pendingOpenSymbol: $pendingOpenSymbol,
        pendingThesisWatchOpen: $pendingThesisWatchOpen
      )
      .environment(portfolioViewModel)
      .navigationDestination(for: PortfolioRootRoute.self) { route in
        switch route {
        case .workspace:
          PortfolioWorkspaceScreen()
        case .scenarioPlanning:
          ProGateView(billingManager: billingManager) { ScenarioPlanningScreen() }
        case .netWorthForecast:
          ProGateView(billingManager: billingManager) { NetWorthForecastScreen() }
        case .smartScreens:
          ProGateView(billingManager: billingManager) { SmartScreeningScreen() }
        case .rebalancingRules:
          ProGateView(billingManager: billingManager) { RebalancingRulesScreen() }
        case .notifications:
          NotificationInboxScreen()
        }
      }
      .navigationDestination(for: PortfolioStockRoute.self) { route in
        StockDetailScreen(stockId: route.stockID, initialSymbol: route.symbol)
      }
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
      .vigilNavigationTitle("Portfolio")
      .aiViewSummary(.portfolio, placement: .topBarLeading)
      .vigilInlineNavigationBar()
      .vigilScreenBackground()
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
          NavigationLink(value: PortfolioRootRoute.workspace) {
            Label("Manage portfolios", systemImage: "rectangle.stack")
          }
          .labelStyle(.iconOnly)
          .accessibilityLabel("Manage portfolios")
          NavigationLink(value: PortfolioRootRoute.scenarioPlanning) {
            Label("Scenario planning", systemImage: "chart.xyaxis.line")
          }
          .labelStyle(.iconOnly)
          .accessibilityLabel("Open scenario planning")
        }
        ToolbarItem(placement: .topBarTrailing) {
          Menu("Automation", systemImage: "wand.and.stars") {
            NavigationLink(value: PortfolioRootRoute.netWorthForecast) {
              Label("Net worth forecast", systemImage: "chart.xyaxis.line")
            }
            NavigationLink(value: PortfolioRootRoute.smartScreens) {
              Label("Smart screens", systemImage: "line.3.horizontal.decrease.circle")
            }
            NavigationLink(value: PortfolioRootRoute.rebalancingRules) {
              Label("Rebalancing rules", systemImage: "scale.3d")
            }
            NavigationLink(value: PortfolioRootRoute.notifications) {
              Label("Notifications", systemImage: "bell")
            }
          }
          .accessibilityLabel("Open wealth automation")
        }
      }
    }
  }
}
