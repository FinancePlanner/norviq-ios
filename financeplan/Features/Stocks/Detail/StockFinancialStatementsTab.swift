import StockPlanShared
import SwiftUI

struct StockFinancialStatementsTab: View {
    let statements: StockFinancialStatements?
    let errorMessage: String?
    @Binding var selectedPeriod: StockFinancialStatementPeriod

    var body: some View {
        LazyVStack(spacing: 16) {
            if let statements {
                FinancialStatementsIntroCard(symbol: statements.symbol)
                FinancialStatementPeriodPicker(selectedPeriod: $selectedPeriod)
                FinancialStatementTableCard(
                    title: "Balance sheet",
                    subtitle: "Review assets, liabilities, and equity across the selected filing period.",
                    statements: statements.balanceSheets(for: selectedPeriod),
                    emptyText: "No balance sheet filings are available for \(selectedPeriod.title)."
                )
                FinancialStatementTableCard(
                    title: "Cash flow",
                    subtitle: "Review operating, investing, and financing cash movements across the selected filing period.",
                    statements: statements.cashFlows(for: selectedPeriod),
                    emptyText: "No cash flow filings are available for \(selectedPeriod.title)."
                )
                FinancialMetricTableCard(
                    title: "Ratios",
                    subtitle: "Review valuation, capital efficiency, returns, and working-capital metrics across the selected filing period.",
                    snapshots: statements.ratios(for: selectedPeriod),
                    emptyText: "No ratio snapshots are available for \(selectedPeriod.title)."
                )
                FinancialMetricTableCard(
                    title: "Financial growth",
                    subtitle: "Review revenue, EPS, cash flow, share count, and long-term per-share growth across the selected filing period.",
                    snapshots: statements.growth(for: selectedPeriod),
                    emptyText: "No growth snapshots are available for \(selectedPeriod.title)."
                )
                FinancialMetricTableCard(
                    title: "Financial estimates",
                    subtitle: "Review forward revenue, EBITDA, EBIT, net income, SG&A, EPS, and analyst-count ranges.",
                    snapshots: statements.estimates,
                    emptyText: "No financial estimates are available right now."
                )
            } else if let errorMessage {
                ResearchPlaceholderCard(
                    title: "Financial statements",
                    bodyText: errorMessage
                )
            } else {
                ResearchPlaceholderCard(
                    title: "Financial statements",
                    bodyText: "Financial statement data is currently unavailable for this symbol."
                )
            }
        }
    }
}
