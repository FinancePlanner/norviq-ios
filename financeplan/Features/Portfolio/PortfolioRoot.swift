import SwiftUI
import Factory
import StockPlanShared

/// Toolbar destinations reached from the portfolio root. Value-based links
/// keep the destination screens (ScenarioPlanningScreen is ~850 lines) from
/// being constructed on every PortfolioRoot body pass.
enum PortfolioRootRoute: Hashable {
  case workspace
  case grow
  case retire
  case simulator
  case scenarioPlanning
  case netWorthForecast
  case smartScreens
  case rebalancingRules
  case notifications
  case terminalPositions
  case crypto
}

@MainActor
struct PortfolioRoot: View {
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
        // Planning is ungated for the same reason the simulator is: it works
        // with no holdings, and "am I on track" is the question people arrive
        // with.
        case .grow:
          GrowScreen()
        case .retire:
          RetireScreen()
        // Deliberately not behind ProGateView: the simulator is the one
        // surface someone with no holdings can use.
        case .simulator:
          PortfolioSimulatorScreen()
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
        // Free, like Grow and Retire: only the AI suggestions inside are Pro.
        case .terminalPositions:
          TerminalPositionsScreen()
        // Gated inside: a free user gets its own Pro gate.
        case .crypto:
          CryptoHomeView()
        }
      }
      .navigationDestination(for: PortfolioStockRoute.self) { route in
        StockDetailScreen(stockId: route.stockID, initialSymbol: route.symbol)
      }
      .pilotDestinations()
      .toolsDestinations()
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
      .qScope(.portfolio)
      .vigilInlineNavigationBar()
      .vigilScreenBackground()
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          NavigationLink(value: PortfolioRootRoute.workspace) {
            Label("Manage portfolios", systemImage: "rectangle.stack")
          }
          .labelStyle(.iconOnly)
          .accessibilityLabel("Manage portfolios")
          NavigationLink(value: PortfolioRootRoute.simulator) {
            Label("Simulator", systemImage: "slider.horizontal.below.square.filled.and.square")
          }
          .labelStyle(.iconOnly)
          NavigationLink(value: PortfolioRootRoute.scenarioPlanning) {
            Label("Scenarios", systemImage: "chart.xyaxis.line")
          }
          .labelStyle(.iconOnly)
          .accessibilityLabel("Open scenarios")
        }
        // A menu rather than two more icons: the top bar already carries four,
        // and these two belong together as one idea - path, and destination.
        ToolbarItem(placement: .topBarTrailing) {
          Menu("Planning", systemImage: "target") {
            NavigationLink(value: ToolsRoute.hub) {
              Label("All tools", systemImage: "wrench.and.screwdriver")
            }
            NavigationLink(value: PortfolioRootRoute.grow) {
              Label("Grow", systemImage: "chart.line.uptrend.xyaxis")
            }
            NavigationLink(value: PortfolioRootRoute.retire) {
              Label("Retirement", systemImage: "beach.umbrella")
            }
            NavigationLink(value: PortfolioRootRoute.terminalPositions) {
              Label("Terminal sizing", systemImage: "scope")
            }
            NavigationLink(value: PortfolioRootRoute.crypto) {
              Label("Crypto", systemImage: "bitcoinsign.circle")
            }
          }
          .accessibilityLabel("Open planning")
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
