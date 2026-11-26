import Factory
import SwiftUI

/// The screen each `AppDestination` pushes, per the destination table's iOS
/// column. Registered on every hub stack with
/// `.navigationDestination(for: AppDestination.self)`.
@ViewBuilder
func destinationView(_ destination: AppDestination) -> some View {
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
    // Task 5: SocialRoot takes More's path; Task 6 passes HomeScreen's pending
    // invite code and section instead of these constants.
    SocialRoot(pendingInviteCode: .constant(nil), pendingSection: .constant(nil))
  case .groups:
    GroupsRoot()
  case .boards:
    BoardsRoot()
  case .settings:
    // Task 5: UserProfileView drops its own NavigationStack.
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
    // Task 5: CryptoHomeView drops this binding, its gear button and its stack.
    CryptoHomeView(isSettingsPresented: .constant(false))
  case .notifications:
    NotificationInboxScreen()
  }
}

/// `destinationView(_:)` is a function and can't hold injected state, so the
/// billing manager for the Pro gate is resolved here.
private struct ProGatedDestination<Content: View>: View {
  @InjectedObservable(\Container.billingManager) private var billingManager
  @ViewBuilder let content: () -> Content

  var body: some View {
    ProGateView(billingManager: billingManager) { content() }
  }
}
