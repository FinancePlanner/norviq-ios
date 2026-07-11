import SwiftUI

/// Trend charts (cash generation, margins, valuation multiples, growth) shown
/// above the financial statement tables. Derived from the statement arrays the
/// tab already holds.
///
/// The FY/Q period picker selects a *single* filing for the tables, so for
/// trends we instead chart a whole series at the matching granularity:
/// annual filings (FY) or quarterly filings (Q*), most recent eight.
struct FinancialTrendCharts: View {
    let statements: StockFinancialStatements
    let selectedPeriod: StockFinancialStatementPeriod

    private enum Granularity { case annual, quarterly }

    private var granularity: Granularity {
        switch selectedPeriod {
        case .annual, .fy: return .annual
        default: return .quarterly
        }
    }

    private func matchesGranularity(_ period: String) -> Bool {
        let upper = period.uppercased()
        switch granularity {
        case .annual: return upper == StockFinancialStatementPeriod.fy.rawValue
        case .quarterly: return upper.hasPrefix("Q")
        }
    }

    private var cashFlowSeries: [StockFinancialStatement] {
        let filtered = statements.cashFlows.filter { matchesGranularity($0.period) }
        return Array(filtered.sorted { $0.date < $1.date }.suffix(8))
    }

    private var ratioSeries: [StockFinancialMetricSnapshot] {
        let filtered = statements.ratios.filter { matchesGranularity($0.normalizedPeriod ?? "") }
        return Array(filtered.sorted { $0.date < $1.date }.suffix(8))
    }

    private var growthSeries: [StockFinancialMetricSnapshot] {
        let filtered = statements.growth.filter { matchesGranularity($0.normalizedPeriod ?? "") }
        return Array(filtered.sorted { $0.date < $1.date }.suffix(8))
    }

    // MARK: Point builders

    private func statementPoints(
        _ series: [StockFinancialStatement],
        metrics: [(id: String, name: String)]
    ) -> [MetricSeriesPoint] {
        series.flatMap { statement -> [MetricSeriesPoint] in
            metrics.compactMap { metric in
                guard let value = statement.value(for: metric.id) else { return nil }
                return MetricSeriesPoint(label: statement.displayColumnTitle, series: metric.name, value: value)
            }
        }
    }

    private func snapshotPoints(
        _ series: [StockFinancialMetricSnapshot],
        metrics: [(id: String, name: String)]
    ) -> [MetricSeriesPoint] {
        series.flatMap { snapshot -> [MetricSeriesPoint] in
            metrics.compactMap { metric in
                guard let value = snapshot.entries.first(where: { $0.id == metric.id })?.value else { return nil }
                return MetricSeriesPoint(label: snapshot.displayColumnTitle, series: metric.name, value: value)
            }
        }
    }

    private var cashGenerationPoints: [MetricSeriesPoint] {
        statementPoints(cashFlowSeries, metrics: [
            ("netIncome", "Net income"),
            ("operatingCashFlow", "Operating CF"),
            ("freeCashFlow", "Free CF")
        ])
    }

    private var marginPoints: [MetricSeriesPoint] {
        snapshotPoints(ratioSeries, metrics: [
            ("grossProfitMargin", "Gross"),
            ("operatingProfitMargin", "Operating"),
            ("netProfitMargin", "Net")
        ])
    }

    private var valuationPoints: [MetricSeriesPoint] {
        snapshotPoints(ratioSeries, metrics: [
            ("priceToEarningsRatio", "P/E"),
            ("priceToBookRatio", "P/B"),
            ("priceToSalesRatio", "P/S")
        ])
    }

    private var growthPoints: [MetricSeriesPoint] {
        snapshotPoints(growthSeries, metrics: [
            ("revenueGrowth", "Revenue"),
            ("netIncomeGrowth", "Net income"),
            ("epsgrowth", "EPS")
        ])
    }

    private var periodNoun: String {
        granularity == .annual ? "fiscal year" : "quarter"
    }

    var body: some View {
        VStack(spacing: 16) {
            if cashGenerationPoints.orderedLabels.count >= 2 {
                ChartCard(
                    title: "Cash generation",
                    subtitle: "Net income, operating cash flow, and free cash flow by \(periodNoun)."
                ) {
                    MetricTrendChart(points: cashGenerationPoints, format: .currencyCompact)
                }
            }

            if marginPoints.orderedLabels.count >= 2 {
                ChartCard(
                    title: "Margins",
                    subtitle: "Gross, operating, and net profit margin by \(periodNoun)."
                ) {
                    MetricTrendChart(points: marginPoints, format: .percentFraction)
                }
            }

            if valuationPoints.orderedLabels.count >= 2 {
                ChartCard(
                    title: "Valuation multiples",
                    subtitle: "Price-to-earnings, price-to-book, and price-to-sales by \(periodNoun)."
                ) {
                    MetricTrendChart(points: valuationPoints, format: .multiple(1))
                }
            }

            if growthPoints.orderedLabels.count >= 2 {
                ChartCard(
                    title: "Growth",
                    subtitle: "Revenue, net income, and EPS growth by \(periodNoun)."
                ) {
                    MetricTrendChart(points: growthPoints, format: .percentFraction)
                }
            }
        }
    }
}
