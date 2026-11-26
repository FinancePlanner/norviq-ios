import Foundation

/// A screen pushed inside one of the five tabs, from a hub or a deep link.
nonisolated enum AppDestination: Hashable, CaseIterable, Sendable {
  // More > Intelligence
  case markets, economy, insights, reports, chartBuilder
  // More > Community
  case friends, groups, boards
  // More > Account
  case settings, brokers
  // Plan
  case goals, netWorthForecast, retirement, scenarios, simulator, grow, tools, tax, terminalSizing
  // Wealth
  case crypto
  // Today
  case notifications
}
