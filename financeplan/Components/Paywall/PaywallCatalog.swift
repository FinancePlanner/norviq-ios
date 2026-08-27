import Foundation

/// Display catalog for paywalls and subscription settings.
///
/// Keys match backend `BillingFeature` raw values. Grouping is presentation only.
enum PaywallCatalog {
  enum Watch: String, CaseIterable, Identifiable {
    case wealth
    case spending
    case intelligence

    var id: String { rawValue }

    var title: String {
      switch self {
      case .wealth: String(localized: "Wealth")
      case .spending: String(localized: "Spending")
      case .intelligence: String(localized: "Intelligence")
      }
    }
  }

  struct Row: Identifiable, Hashable {
    let id: String
    let title: String
    let watch: Watch
    let includedInFree: Bool
    let includedInPro: Bool
  }

  struct Group: Identifiable {
    var id: String { watch.rawValue }
    let watch: Watch
    let rows: [Row]
  }

  static let rows: [Row] = [
    Row(id: "holdings", title: "Holdings and watchlists", watch: .wealth, includedInFree: true, includedInPro: true),
    Row(id: "goal_planning", title: "One active financial goal", watch: .wealth, includedInFree: true, includedInPro: true),
    Row(id: "broker_sync", title: "Broker sync", watch: .wealth, includedInFree: false, includedInPro: true),
    Row(id: "target_alerts", title: "Price, dividend, and earnings alerts", watch: .wealth, includedInFree: false, includedInPro: true),
    Row(id: "market_fundamentals", title: "Fundamentals, statements, and research", watch: .wealth, includedInFree: false, includedInPro: true),
    Row(id: "valuation_cases", title: "Chart builder and projections", watch: .wealth, includedInFree: false, includedInPro: true),
    Row(id: "scenario_planning", title: "Scenario planning", watch: .wealth, includedInFree: false, includedInPro: true),
    Row(id: "net_worth_forecasting", title: "Net worth forecast", watch: .wealth, includedInFree: false, includedInPro: true),
    Row(id: "smart_screening", title: "Smart watchlist screens", watch: .wealth, includedInFree: false, includedInPro: true),
    Row(id: "rebalancing_rules", title: "Rebalancing rules", watch: .wealth, includedInFree: false, includedInPro: true),
    Row(id: "advanced_portfolios", title: "Retirement and hypothetical portfolios", watch: .wealth, includedInFree: false, includedInPro: true),
    Row(id: "crypto", title: "Crypto", watch: .wealth, includedInFree: false, includedInPro: true),
    Row(id: "expense_planner", title: "Core budgets and expenses", watch: .spending, includedInFree: true, includedInPro: true),
    Row(id: "bank_sync", title: "Read-only bank sync", watch: .spending, includedInFree: false, includedInPro: true),
    Row(id: "receipt_scan", title: "Receipt scanning", watch: .spending, includedInFree: false, includedInPro: true),
    Row(id: "household_partner", title: "Household split view", watch: .spending, includedInFree: false, includedInPro: true),
    Row(id: "recurring_templates", title: "Recurring expense templates", watch: .spending, includedInFree: false, includedInPro: true),
    Row(id: "year_overview", title: "Year-over-year expense history", watch: .spending, includedInFree: false, includedInPro: true),
    Row(id: "smart_suggestions", title: "Smart spending suggestions", watch: .spending, includedInFree: false, includedInPro: true),
    Row(id: "reports", title: "Basic reports", watch: .intelligence, includedInFree: true, includedInPro: true),
    Row(id: "ai_insights", title: "Q and insights", watch: .intelligence, includedInFree: false, includedInPro: true),
    Row(id: "mcp_access", title: "MCP integrations", watch: .intelligence, includedInFree: false, includedInPro: true),
    Row(id: "tax_optimization", title: "Tax strategy", watch: .intelligence, includedInFree: false, includedInPro: true),
    Row(id: "advanced_report_runs", title: "Advanced and scheduled reports", watch: .intelligence, includedInFree: false, includedInPro: true),
  ]

  static var groups: [Group] {
    Watch.allCases.map { watch in
      Group(watch: watch, rows: rows.filter { $0.watch == watch })
    }
  }
}
