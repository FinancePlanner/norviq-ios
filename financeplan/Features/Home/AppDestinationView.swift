import Factory
import SwiftUI

/// The screen each `AppDestination` pushes, per the destination table's iOS
/// column. Registered on every hub stack with
/// `.navigationDestination(for: AppDestination.self)`.
///
/// - Parameters:
///   - path: the hub's path, which Friends and Groups push their own routes onto.
///   - pendingInviteCode: an invite link waiting for Friends.
///   - pendingSocialSection: a Friends section a push asked for.
@ViewBuilder
func destinationView(
  _ destination: AppDestination,
  path: Binding<NavigationPath>,
  pendingInviteCode: Binding<String?>,
  pendingSocialSection: Binding<String?>
) -> some View {
  switch destination {
  case .markets:
    MarketsScreen()
  case .economy:
    EconomyHubScreen()
  // The row opens the paywall for free users; the gate covers deep links,
  // which push without the row.
  case .insights:
    ProGatedDestination { InsightsScreen() }
  case .reports:
    ExpensesComparisonScreen()
  case .chartBuilder:
    ChartBuilderStandaloneScreen()
  case .friends:
    SocialRoot(path: path, pendingInviteCode: pendingInviteCode, pendingSection: pendingSocialSection)
  case .groups:
    GroupsRoot(path: path)
  case .boards:
    BoardsRoot()
  case .settings:
    UserProfileView()
  case .brokers:
    IntegrationsView()
  case .goals:
    GoalPlanningScreen()
  case .netWorthForecast:
    ProGatedDestination { NetWorthForecastScreen() }
  case .retirement:
    RetireScreen()
  case .scenarios:
    ProGatedDestination { ScenarioPlanningScreen() }
  case .simulator:
    PortfolioSimulatorScreen()
  case .grow:
    GrowScreen()
  case .tools:
    ToolsScreen()
  case .tax:
    TaxDashboardScreen()
  case .terminalSizing:
    TerminalPositionsScreen()
  case .crypto:
    CryptoHomeView()
  case .notifications:
    NotificationInboxScreen()
  }
}

/// `destinationView` is a function and can't hold injected state, so the
/// billing manager for the Pro gate is resolved here.
private struct ProGatedDestination<Content: View>: View {
  @InjectedObservable(\Container.billingManager) private var billingManager
  @ViewBuilder let content: () -> Content

  var body: some View {
    ProGateView(billingManager: billingManager) { content() }
  }
}
