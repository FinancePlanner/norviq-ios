import Foundation
import Testing
@testable import StockPlanShared

@Test func chartBuilderCatalogHasUniqueKeys() {
    let keys = ChartBuilderMetricCatalog.all.map(\.key)
    #expect(Set(keys).count == keys.count)
}

@Test func chartBuilderCatalogEveryGroupNonEmpty() {
    for group in ChartMetricGroup.allCases {
        #expect(!ChartBuilderMetricCatalog.metrics(in: group).isEmpty, "empty group: \(group)")
    }
}

@Test func chartBuilderBalanceSheetMetricsAreAllPointInTime() {
    for metric in ChartBuilderMetricCatalog.metrics(in: .balanceSheet) {
        #expect(metric.aggregation == .pointInTime, "not pointInTime: \(metric.key)")
    }
}

@Test func chartBuilderGrowthMetricsDoNotSupportTTM() {
    for metric in ChartBuilderMetricCatalog.metrics(in: .growth) {
        #expect(!metric.supportsTTM, "growth metric supports TTM: \(metric.key)")
    }
}

@Test func chartBuilderRatioAggregationOnlySupportsTTMForMargins() {
    for metric in ChartBuilderMetricCatalog.all where metric.aggregation == .ratio && metric.supportsTTM {
        #expect(metric.format == .percent, "non-percent ratio supports TTM: \(metric.key)")
    }
}

@Test func chartBuilderDescriptorRoundTripJSON() throws {
    let descriptor = try #require(ChartBuilderMetricCatalog.byKey["freeCashFlow"])
    let encoded = try JSONEncoder().encode(descriptor)
    let decoded = try JSONDecoder().decode(ChartMetricDescriptor.self, from: encoded)
    #expect(decoded == descriptor)
    #expect(descriptor.label == "Free Cash Flow")
    #expect(descriptor.group == .cashFlow)
    #expect(descriptor.aggregation == .flow)
}

@Test func chartBuilderLabelGeneration() {
    #expect(ChartBuilderMetricCatalog
        .label(for: "netCashProvidedByOperatingActivities") == "Net Cash from Operating Activities")
    #expect(ChartBuilderMetricCatalog.label(for: "eps") == "EPS")
    #expect(ChartBuilderMetricCatalog.label(for: "tenYRevenueGrowthPerShare") == "10Y Revenue Growth per Share")
    #expect(ChartBuilderMetricCatalog.label(for: "totalStockholdersEquity") == "Total Stockholders Equity")
    #expect(ChartBuilderMetricCatalog.label(for: "changeInWorkingCapital") == "Change in Working Capital")
}

@Test func chartBuilderResponseRoundTripJSON() throws {
    let response = ChartBuilderResponse(
        period: .ttm,
        periods: [
            ChartBuilderPeriod(label: "TTM Q3 2024", fiscalYear: "2024", fiscalPeriod: "Q3", endDate: "2024-09-28"),
        ],
        series: [
            ChartBuilderSeries(
                symbol: "AAPL",
                metricKey: "freeCashFlow",
                label: "Free Cash Flow",
                format: .currency,
                currency: "USD",
                values: [104_338_000_000, nil],
                growth: ChartBuilderGrowthStats(
                    yoy: [ChartBuilderGrowthPoint(periodLabel: "TTM Q3 2024", absolute: 2_100_000_000, percent: 0.046)],
                    totalChange: 36_100_000_000,
                    totalChangePercent: 2.977,
                    cagr: 0.039
                )
            ),
        ],
        companies: [ChartBuilderCompany(symbol: "AAPL", name: "Apple Inc.", currency: "USD")]
    )
    let encoded = try JSONEncoder().encode(response)
    let decoded = try JSONDecoder().decode(ChartBuilderResponse.self, from: encoded)
    #expect(decoded == response)
}

@Test func chartBuilderCatalogResponseGroupsInDeclarationOrder() {
    let catalog = ChartBuilderMetricCatalogResponse.current()
    #expect(catalog.groups.map(\.key) == ChartMetricGroup.allCases)
    #expect(catalog.groups.allSatisfy { !$0.metrics.isEmpty })
}
