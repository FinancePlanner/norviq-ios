import Foundation
import StockPlanShared

enum StockDetailTab: String, CaseIterable, Identifiable {
    case chart
    case overview
    case statements
    case analysis
    case forecast
    case compare
    case news
    case earnings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chart:
            "Chart"
        case .overview:
            "Overview"
        case .statements:
            "Statements"
        case .analysis:
            "Analysis"
        case .forecast:
            "Forecast"
        case .compare:
            "Compare"
        case .news:
            "News"
        case .earnings:
            "Earnings"
        }
    }
}

enum StockProjectionScenarioKind: String, CaseIterable, Identifiable {
    case bear
    case base
    case bull

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bear:
            "Bear"
        case .base:
            "Base"
        case .bull:
            "Bull"
        }
    }

    var subtitle: String {
        switch self {
        case .bear:
            "Lower growth, lower multiple, more conservative outcomes."
        case .base:
            "Most likely operating path using balanced assumptions."
        case .bull:
            "Higher growth, stronger margins, and better exit multiples."
        }
    }
}

enum StockComparisonMetricGroup: String, CaseIterable, Identifiable {
    case mandatory
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mandatory:
            "Mandatory Metrics"
        case .advanced:
            "Advanced Metrics"
        }
    }
}

extension StockComparisonMetricGroup {
    var metrics: [StockComparisonMetric] {
        StockComparisonMetric.allCases.filter { $0.group == self }
    }
}

enum StockMetricValueFormat {
    case multiple
    case percent
    case plain
}

enum StockComparisonMetric: String, CaseIterable, Identifiable {
    case ttmPE
    case forwardPE
    case twoYearForwardPE
    case ttmEPSGrowth
    case currentYearExpectedEPSGrowth
    case nextYearEPSGrowth
    case ttmRevenueGrowth
    case currentYearExpectedRevenueGrowth
    case nextYearRevenueGrowth
    case grossMargin
    case netMargin
    case ttmPEGRatio
    case lastYearEPSGrowth
    case ttmVsNTMEPSGrowth
    case currentQuarterEPSGrowthVsPreviousYear
    case twoYearStackExpectedEPSGrowth
    case lastYearRevenueGrowth
    case ttmVsNTMRevenueGrowth
    case currentQuarterRevenueGrowthVsPreviousYear
    case twoYearStackExpectedRevenueGrowth
    case dcfFairValue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ttmPE:
            "TTM PE"
        case .forwardPE:
            "Forward PE"
        case .twoYearForwardPE:
            "2 Year Forward PE"
        case .ttmEPSGrowth:
            "TTM EPS Growth"
        case .currentYearExpectedEPSGrowth:
            "Current Yr Exp EPS Growth"
        case .nextYearEPSGrowth:
            "Next Year EPS Growth"
        case .ttmRevenueGrowth:
            "TTM Rev Growth"
        case .currentYearExpectedRevenueGrowth:
            "Current Yr Exp Rev Growth"
        case .nextYearRevenueGrowth:
            "Next Year Rev Growth"
        case .grossMargin:
            "Gross Margin"
        case .netMargin:
            "Net Margin"
        case .ttmPEGRatio:
            "TTM PEG Ratio"
        case .lastYearEPSGrowth:
            "Last Year EPS Growth"
        case .ttmVsNTMEPSGrowth:
            "TTM vs NTM EPS Growth"
        case .currentQuarterEPSGrowthVsPreviousYear:
            "Current Quarter EPS Growth vs Previous Year"
        case .twoYearStackExpectedEPSGrowth:
            "2 Year Stack Exp EPS Growth"
        case .lastYearRevenueGrowth:
            "Last Year Rev Growth"
        case .ttmVsNTMRevenueGrowth:
            "TTM vs NTM Rev Growth"
        case .currentQuarterRevenueGrowthVsPreviousYear:
            "Current Quarter Rev Growth vs Previous Year"
        case .twoYearStackExpectedRevenueGrowth:
            "2 Year Stack Exp Rev Growth"
        case .dcfFairValue:
            "DCF Fair Value (Base)"
        }
    }

    var group: StockComparisonMetricGroup {
        switch self {
        case .ttmPE, .forwardPE, .twoYearForwardPE, .ttmEPSGrowth, .currentYearExpectedEPSGrowth,
             .nextYearEPSGrowth, .ttmRevenueGrowth, .currentYearExpectedRevenueGrowth,
             .nextYearRevenueGrowth, .grossMargin, .netMargin, .ttmPEGRatio, .dcfFairValue:
            .mandatory
        case .lastYearEPSGrowth, .ttmVsNTMEPSGrowth, .currentQuarterEPSGrowthVsPreviousYear,
             .twoYearStackExpectedEPSGrowth, .lastYearRevenueGrowth, .ttmVsNTMRevenueGrowth,
             .currentQuarterRevenueGrowthVsPreviousYear, .twoYearStackExpectedRevenueGrowth:
            .advanced
        }
    }

    var format: StockMetricValueFormat {
        switch self {
        case .ttmPE, .forwardPE, .twoYearForwardPE, .ttmPEGRatio:
            .multiple
        case .dcfFairValue:
            .plain
        case .ttmEPSGrowth, .currentYearExpectedEPSGrowth, .nextYearEPSGrowth,
             .ttmRevenueGrowth, .currentYearExpectedRevenueGrowth, .nextYearRevenueGrowth,
             .grossMargin, .netMargin, .lastYearEPSGrowth, .ttmVsNTMEPSGrowth,
             .currentQuarterEPSGrowthVsPreviousYear, .twoYearStackExpectedEPSGrowth,
             .lastYearRevenueGrowth, .ttmVsNTMRevenueGrowth,
             .currentQuarterRevenueGrowthVsPreviousYear, .twoYearStackExpectedRevenueGrowth:
            .percent
        }
    }

    var benchmarkText: String {
        switch self {
        case .ttmPE:
            "Many quality stocks trade at 18x - 28x."
        case .forwardPE:
            "Many quality stocks trade at 16x - 24x."
        case .twoYearForwardPE:
            "Many quality stocks trade at 14x - 22x."
        case .ttmEPSGrowth:
            "Many quality stocks grow EPS at 8% - 18%."
        case .currentYearExpectedEPSGrowth:
            "Many quality stocks grow EPS at 10% - 20%."
        case .nextYearEPSGrowth:
            "Many quality stocks grow EPS at 12% - 24%."
        case .ttmRevenueGrowth:
            "Many quality stocks grow revenue at 6% - 14%."
        case .currentYearExpectedRevenueGrowth:
            "Many quality stocks grow revenue at 7% - 15%."
        case .nextYearRevenueGrowth:
            "Many quality stocks grow revenue at 8% - 16%."
        case .grossMargin:
            "Many quality stocks report 45% - 70% gross margins."
        case .netMargin:
            "Many quality stocks report 15% - 30% net margins."
        case .ttmPEGRatio:
            "Many quality stocks trade around 1.2x - 2.2x PEG."
        case .lastYearEPSGrowth:
            "Many quality stocks delivered 5% - 18% EPS growth."
        case .ttmVsNTMEPSGrowth:
            "Many quality stocks show 2% - 8% EPS acceleration."
        case .currentQuarterEPSGrowthVsPreviousYear:
            "Many quality stocks print 8% - 20% quarterly EPS growth."
        case .twoYearStackExpectedEPSGrowth:
            "Many quality stocks compound EPS at 18% - 35% over two years."
        case .lastYearRevenueGrowth:
            "Many quality stocks delivered 4% - 14% revenue growth."
        case .ttmVsNTMRevenueGrowth:
            "Many quality stocks show 1% - 5% revenue acceleration."
        case .currentQuarterRevenueGrowthVsPreviousYear:
            "Many quality stocks print 5% - 15% quarterly revenue growth."
        case .twoYearStackExpectedRevenueGrowth:
            "Many quality stocks compound revenue at 10% - 22% over two years."
        case .dcfFairValue:
            "Intrinsic value per share using Discounted Cash Flow."
        }
    }
}

struct StockProjectionYear: Identifiable, Equatable {
    var id: Int { year }

    let year: Int
    let revenue: Double
    let revenueGrowth: Double
    let netIncome: Double
    let netIncomeGrowth: Double
    let netMargin: Double
    let eps: Double
    let freeCashFlow: Double?
    let peLowEstimate: Double
    let peHighEstimate: Double
    let sharePriceLow: Double
    let sharePriceHigh: Double
    let cagrLow: Double?
    let cagrHigh: Double?
}

struct StockProjectionScenario: Equatable {
    let kind: StockProjectionScenarioKind
    let currentPrice: Double
    let marketCap: Double
    let sharesOutstanding: Double
    let years: [StockProjectionYear]
}

public typealias StockMarketSnapshot = QuoteResponse

struct StockComparisonProfile: Identifiable, Equatable {
    var id: String { symbol }

    let symbol: String
    let companyName: String
    let currentPrice: Double
    let marketCap: Double
    let sharesOutstanding: Double
    let metrics: [StockComparisonMetric: Double]
    let projectionScenarios: [StockProjectionScenarioKind: StockProjectionScenario]
    let dcfBasePrice: Double?
    let dcfBearPrice: Double?
    let dcfBullPrice: Double?
}

// to fill from endpoint later
enum StockInsightsMockStore {
    private static let actualYear = 2024
    private static let projectionYears = [2025, 2026, 2027, 2028]

    static func universe(for primarySymbol: String) -> [StockComparisonProfile] {
        let primary = profile(for: primarySymbol)
        let peers = seedLookup.values
            .filter { $0.symbol != primary.symbol }
            .sorted { $0.symbol < $1.symbol }
            .map(makeProfile(from:))

        return [primary] + peers
    }

    static func profile(for symbol: String) -> StockComparisonProfile {
        if let seed = seedLookup[symbol.uppercased()] {
            return makeProfile(from: seed)
        }

        return makeProfile(
            from: StockInsightSeed(
                symbol: symbol.uppercased(),
                companyName: "\(symbol.uppercased()) Holdings",
                currentPrice: 184,
                marketCap: 420_000_000_000,
                sharesOutstanding: 2_180_000_000,
                actualRevenue: 78_500_000_000,
                actualNetIncome: 16_200_000_000,
                metrics: metrics(
                    ttmPE: 24.4,
                    forwardPE: 20.6,
                    twoYearForwardPE: 18.8,
                    ttmEPSGrowth: 0.18,
                    currentYearExpectedEPSGrowth: 0.16,
                    nextYearEPSGrowth: 0.17,
                    ttmRevenueGrowth: 0.11,
                    currentYearExpectedRevenueGrowth: 0.10,
                    nextYearRevenueGrowth: 0.11,
                    grossMargin: 0.61,
                    netMargin: 0.21,
                    ttmPEGRatio: 1.52,
                    lastYearEPSGrowth: 0.14,
                    ttmVsNTMEPSGrowth: 0.03,
                    currentQuarterEPSGrowthVsPreviousYear: 0.10,
                    twoYearStackExpectedEPSGrowth: 0.31,
                    lastYearRevenueGrowth: 0.09,
                    ttmVsNTMRevenueGrowth: 0.02,
                    currentQuarterRevenueGrowthVsPreviousYear: 0.08,
                    twoYearStackExpectedRevenueGrowth: 0.19
                ),
                scenarioSeeds: scenarioSeeds(
                    bear: projectionSeed(
                        revenueGrowth: [0.07, 0.07, 0.06, 0.06],
                        netMargin: [0.20, 0.20, 0.19, 0.19],
                        peLow: [16, 16, 15, 15],
                        peHigh: [19, 19, 18, 18]
                    ),
                    base: projectionSeed(
                        revenueGrowth: [0.10, 0.10, 0.09, 0.09],
                        netMargin: [0.22, 0.22, 0.22, 0.22],
                        peLow: [18, 18, 18, 17],
                        peHigh: [22, 22, 21, 21]
                    ),
                    bull: projectionSeed(
                        revenueGrowth: [0.13, 0.13, 0.12, 0.12],
                        netMargin: [0.24, 0.24, 0.25, 0.25],
                        peLow: [21, 21, 20, 20],
                        peHigh: [26, 26, 25, 25]
                    )
                )
            )
        )
    }

    private static let seedLookup: [String: StockInsightSeed] = [
        "META": StockInsightSeed(
            symbol: "META",
            companyName: "Meta Platforms",
            currentPrice: 497.74,
            marketCap: 1_270_000_000_000,
            sharesOutstanding: 2_561_000_000,
            actualRevenue: 161_302_000_000,
            actualNetIncome: 53_534_436_140,
            metrics: metrics(
                ttmPE: 24.9,
                forwardPE: 19.4,
                twoYearForwardPE: 16.7,
                ttmEPSGrowth: 0.73,
                currentYearExpectedEPSGrowth: 0.22,
                nextYearEPSGrowth: 0.18,
                ttmRevenueGrowth: 0.22,
                currentYearExpectedRevenueGrowth: 0.16,
                nextYearRevenueGrowth: 0.14,
                grossMargin: 0.81,
                netMargin: 0.33,
                ttmPEGRatio: 1.28,
                lastYearEPSGrowth: 0.77,
                ttmVsNTMEPSGrowth: 0.11,
                currentQuarterEPSGrowthVsPreviousYear: 0.32,
                twoYearStackExpectedEPSGrowth: 0.56,
                lastYearRevenueGrowth: 0.16,
                ttmVsNTMRevenueGrowth: 0.05,
                currentQuarterRevenueGrowthVsPreviousYear: 0.19,
                twoYearStackExpectedRevenueGrowth: 0.31
            ),
            scenarioSeeds: scenarioSeeds(
                bear: projectionSeed(
                    revenueGrowth: [0.09, 0.08, 0.07, 0.06],
                    netMargin: [0.29, 0.28, 0.28, 0.27],
                    peLow: [17, 16, 16, 15],
                    peHigh: [20, 19, 19, 18]
                ),
                base: projectionSeed(
                    revenueGrowth: [0.13, 0.12, 0.11, 0.10],
                    netMargin: [0.31, 0.31, 0.30, 0.30],
                    peLow: [19, 19, 18, 18],
                    peHigh: [24, 23, 23, 22]
                ),
                bull: projectionSeed(
                    revenueGrowth: [0.17, 0.16, 0.14, 0.13],
                    netMargin: [0.33, 0.33, 0.32, 0.32],
                    peLow: [22, 21, 21, 20],
                    peHigh: [28, 27, 27, 26]
                )
            )
        ),
        "NVDA": StockInsightSeed(
            symbol: "NVDA",
            companyName: "NVIDIA",
            currentPrice: 122.34,
            marketCap: 2_990_000_000_000,
            sharesOutstanding: 24_500_000_000,
            actualRevenue: 130_500_000_000,
            actualNetIncome: 72_880_000_000,
            metrics: metrics(
                ttmPE: 62.2,
                forwardPE: 35.8,
                twoYearForwardPE: 27.4,
                ttmEPSGrowth: 1.52,
                currentYearExpectedEPSGrowth: 0.48,
                nextYearEPSGrowth: 0.34,
                ttmRevenueGrowth: 1.26,
                currentYearExpectedRevenueGrowth: 0.47,
                nextYearRevenueGrowth: 0.28,
                grossMargin: 0.76,
                netMargin: 0.56,
                ttmPEGRatio: 1.12,
                lastYearEPSGrowth: 2.18,
                ttmVsNTMEPSGrowth: 0.10,
                currentQuarterEPSGrowthVsPreviousYear: 0.81,
                twoYearStackExpectedEPSGrowth: 0.89,
                lastYearRevenueGrowth: 1.26,
                ttmVsNTMRevenueGrowth: 0.06,
                currentQuarterRevenueGrowthVsPreviousYear: 0.69,
                twoYearStackExpectedRevenueGrowth: 0.52
            ),
            scenarioSeeds: scenarioSeeds(
                bear: projectionSeed(
                    revenueGrowth: [0.20, 0.18, 0.16, 0.14],
                    netMargin: [0.47, 0.46, 0.45, 0.44],
                    peLow: [25, 24, 23, 22],
                    peHigh: [31, 30, 29, 28]
                ),
                base: projectionSeed(
                    revenueGrowth: [0.28, 0.25, 0.22, 0.19],
                    netMargin: [0.50, 0.49, 0.48, 0.47],
                    peLow: [29, 28, 27, 26],
                    peHigh: [36, 35, 34, 33]
                ),
                bull: projectionSeed(
                    revenueGrowth: [0.36, 0.32, 0.28, 0.24],
                    netMargin: [0.53, 0.52, 0.51, 0.50],
                    peLow: [33, 32, 31, 30],
                    peHigh: [41, 40, 39, 38]
                )
            )
        ),
        "AMD": StockInsightSeed(
            symbol: "AMD",
            companyName: "Advanced Micro Devices",
            currentPrice: 168.92,
            marketCap: 276_000_000_000,
            sharesOutstanding: 1_620_000_000,
            actualRevenue: 25_800_000_000,
            actualNetIncome: 3_900_000_000,
            metrics: metrics(
                ttmPE: 52.4,
                forwardPE: 38.6,
                twoYearForwardPE: 29.2,
                ttmEPSGrowth: 0.44,
                currentYearExpectedEPSGrowth: 0.33,
                nextYearEPSGrowth: 0.29,
                ttmRevenueGrowth: 0.18,
                currentYearExpectedRevenueGrowth: 0.16,
                nextYearRevenueGrowth: 0.15,
                grossMargin: 0.53,
                netMargin: 0.15,
                ttmPEGRatio: 1.71,
                lastYearEPSGrowth: 0.26,
                ttmVsNTMEPSGrowth: 0.05,
                currentQuarterEPSGrowthVsPreviousYear: 0.27,
                twoYearStackExpectedEPSGrowth: 0.42,
                lastYearRevenueGrowth: 0.10,
                ttmVsNTMRevenueGrowth: 0.03,
                currentQuarterRevenueGrowthVsPreviousYear: 0.19,
                twoYearStackExpectedRevenueGrowth: 0.27
            ),
            scenarioSeeds: scenarioSeeds(
                bear: projectionSeed(
                    revenueGrowth: [0.09, 0.08, 0.08, 0.07],
                    netMargin: [0.14, 0.14, 0.15, 0.15],
                    peLow: [24, 23, 22, 21],
                    peHigh: [29, 28, 27, 26]
                ),
                base: projectionSeed(
                    revenueGrowth: [0.14, 0.13, 0.12, 0.11],
                    netMargin: [0.16, 0.17, 0.17, 0.18],
                    peLow: [27, 26, 25, 24],
                    peHigh: [33, 32, 31, 30]
                ),
                bull: projectionSeed(
                    revenueGrowth: [0.18, 0.17, 0.16, 0.14],
                    netMargin: [0.18, 0.19, 0.20, 0.20],
                    peLow: [30, 29, 28, 27],
                    peHigh: [37, 36, 35, 34]
                )
            )
        ),
        "AAPL": StockInsightSeed(
            symbol: "AAPL",
            companyName: "Apple",
            currentPrice: 228.10,
            marketCap: 3_450_000_000_000,
            sharesOutstanding: 15_400_000_000,
            actualRevenue: 391_000_000_000,
            actualNetIncome: 99_800_000_000,
            metrics: metrics(
                ttmPE: 31.4,
                forwardPE: 28.1,
                twoYearForwardPE: 24.7,
                ttmEPSGrowth: 0.13,
                currentYearExpectedEPSGrowth: 0.10,
                nextYearEPSGrowth: 0.11,
                ttmRevenueGrowth: 0.06,
                currentYearExpectedRevenueGrowth: 0.05,
                nextYearRevenueGrowth: 0.06,
                grossMargin: 0.46,
                netMargin: 0.26,
                ttmPEGRatio: 2.18,
                lastYearEPSGrowth: 0.09,
                ttmVsNTMEPSGrowth: 0.02,
                currentQuarterEPSGrowthVsPreviousYear: 0.11,
                twoYearStackExpectedEPSGrowth: 0.21,
                lastYearRevenueGrowth: 0.02,
                ttmVsNTMRevenueGrowth: 0.01,
                currentQuarterRevenueGrowthVsPreviousYear: 0.05,
                twoYearStackExpectedRevenueGrowth: 0.10
            ),
            scenarioSeeds: scenarioSeeds(
                bear: projectionSeed(
                    revenueGrowth: [0.03, 0.03, 0.02, 0.02],
                    netMargin: [0.25, 0.25, 0.24, 0.24],
                    peLow: [21, 20, 20, 19],
                    peHigh: [25, 24, 24, 23]
                ),
                base: projectionSeed(
                    revenueGrowth: [0.05, 0.05, 0.04, 0.04],
                    netMargin: [0.26, 0.26, 0.26, 0.26],
                    peLow: [24, 24, 23, 23],
                    peHigh: [28, 28, 27, 27]
                ),
                bull: projectionSeed(
                    revenueGrowth: [0.07, 0.07, 0.06, 0.06],
                    netMargin: [0.28, 0.28, 0.27, 0.27],
                    peLow: [27, 27, 26, 26],
                    peHigh: [32, 32, 31, 31]
                )
            )
        ),
        "MSFT": StockInsightSeed(
            symbol: "MSFT",
            companyName: "Microsoft",
            currentPrice: 468.50,
            marketCap: 3_490_000_000_000,
            sharesOutstanding: 7_440_000_000,
            actualRevenue: 245_000_000_000,
            actualNetIncome: 88_100_000_000,
            metrics: metrics(
                ttmPE: 35.8,
                forwardPE: 30.4,
                twoYearForwardPE: 26.0,
                ttmEPSGrowth: 0.19,
                currentYearExpectedEPSGrowth: 0.16,
                nextYearEPSGrowth: 0.15,
                ttmRevenueGrowth: 0.15,
                currentYearExpectedRevenueGrowth: 0.13,
                nextYearRevenueGrowth: 0.12,
                grossMargin: 0.69,
                netMargin: 0.36,
                ttmPEGRatio: 1.89,
                lastYearEPSGrowth: 0.21,
                ttmVsNTMEPSGrowth: 0.03,
                currentQuarterEPSGrowthVsPreviousYear: 0.18,
                twoYearStackExpectedEPSGrowth: 0.31,
                lastYearRevenueGrowth: 0.14,
                ttmVsNTMRevenueGrowth: 0.02,
                currentQuarterRevenueGrowthVsPreviousYear: 0.14,
                twoYearStackExpectedRevenueGrowth: 0.23
            ),
            scenarioSeeds: scenarioSeeds(
                bear: projectionSeed(
                    revenueGrowth: [0.08, 0.08, 0.07, 0.07],
                    netMargin: [0.34, 0.34, 0.33, 0.33],
                    peLow: [24, 24, 23, 23],
                    peHigh: [29, 29, 28, 28]
                ),
                base: projectionSeed(
                    revenueGrowth: [0.11, 0.11, 0.10, 0.10],
                    netMargin: [0.36, 0.36, 0.36, 0.35],
                    peLow: [27, 27, 26, 26],
                    peHigh: [33, 33, 32, 32]
                ),
                bull: projectionSeed(
                    revenueGrowth: [0.14, 0.14, 0.13, 0.12],
                    netMargin: [0.38, 0.38, 0.38, 0.37],
                    peLow: [30, 30, 29, 29],
                    peHigh: [37, 37, 36, 36]
                )
            )
        ),
        "GOOGL": StockInsightSeed(
            symbol: "GOOGL",
            companyName: "Alphabet",
            currentPrice: 192.46,
            marketCap: 2_360_000_000_000,
            sharesOutstanding: 12_300_000_000,
            actualRevenue: 350_000_000_000,
            actualNetIncome: 100_500_000_000,
            metrics: metrics(
                ttmPE: 26.1,
                forwardPE: 22.5,
                twoYearForwardPE: 19.7,
                ttmEPSGrowth: 0.26,
                currentYearExpectedEPSGrowth: 0.18,
                nextYearEPSGrowth: 0.16,
                ttmRevenueGrowth: 0.14,
                currentYearExpectedRevenueGrowth: 0.11,
                nextYearRevenueGrowth: 0.10,
                grossMargin: 0.58,
                netMargin: 0.29,
                ttmPEGRatio: 1.46,
                lastYearEPSGrowth: 0.24,
                ttmVsNTMEPSGrowth: 0.04,
                currentQuarterEPSGrowthVsPreviousYear: 0.22,
                twoYearStackExpectedEPSGrowth: 0.34,
                lastYearRevenueGrowth: 0.12,
                ttmVsNTMRevenueGrowth: 0.02,
                currentQuarterRevenueGrowthVsPreviousYear: 0.13,
                twoYearStackExpectedRevenueGrowth: 0.21
            ),
            scenarioSeeds: scenarioSeeds(
                bear: projectionSeed(
                    revenueGrowth: [0.07, 0.07, 0.06, 0.06],
                    netMargin: [0.27, 0.27, 0.26, 0.26],
                    peLow: [18, 18, 17, 17],
                    peHigh: [22, 22, 21, 21]
                ),
                base: projectionSeed(
                    revenueGrowth: [0.10, 0.09, 0.09, 0.08],
                    netMargin: [0.29, 0.29, 0.28, 0.28],
                    peLow: [21, 21, 20, 20],
                    peHigh: [25, 25, 24, 24]
                ),
                bull: projectionSeed(
                    revenueGrowth: [0.13, 0.12, 0.11, 0.10],
                    netMargin: [0.31, 0.31, 0.30, 0.30],
                    peLow: [24, 24, 23, 23],
                    peHigh: [29, 29, 28, 28]
                )
            )
        )
    ]

    private static func makeProfile(from seed: StockInsightSeed) -> StockComparisonProfile {
        StockComparisonProfile(
            symbol: seed.symbol,
            companyName: seed.companyName,
            currentPrice: seed.currentPrice,
            marketCap: seed.marketCap,
            sharesOutstanding: seed.sharesOutstanding,
            metrics: seed.metrics,
            projectionScenarios: Dictionary(
                uniqueKeysWithValues: StockProjectionScenarioKind.allCases.map { kind in
                    (kind, makeScenario(from: seed, kind: kind))
                }
            ),
            dcfBasePrice: nil,
            dcfBearPrice: nil,
            dcfBullPrice: nil
        )
    }

    private static func makeScenario(
        from seed: StockInsightSeed,
        kind: StockProjectionScenarioKind
    ) -> StockProjectionScenario {
        let actualEPS = seed.actualNetIncome / seed.sharesOutstanding
        let actualPELow = max((seed.metrics[.forwardPE] ?? 20) * 0.9, 8)
        let actualPEHigh = max((seed.metrics[.ttmPE] ?? actualPELow) * 1.05, actualPELow + 1)
        let actualNetMargin = seed.actualNetIncome / seed.actualRevenue
        let actualRevenueGrowth = seed.metrics[.ttmRevenueGrowth] ?? 0
        let actualNetIncomeGrowth = seed.metrics[.ttmEPSGrowth] ?? 0

        var years: [StockProjectionYear] = [
            StockProjectionYear(
                year: actualYear,
                revenue: seed.actualRevenue,
                revenueGrowth: actualRevenueGrowth,
                netIncome: seed.actualNetIncome,
                netIncomeGrowth: actualNetIncomeGrowth,
                netMargin: actualNetMargin,
                eps: actualEPS,
                freeCashFlow: nil,
                peLowEstimate: actualPELow,
                peHighEstimate: actualPEHigh,
                sharePriceLow: actualEPS * actualPELow,
                sharePriceHigh: actualEPS * actualPEHigh,
                cagrLow: nil,
                cagrHigh: nil
            )
        ]

        guard let scenarioSeed = seed.scenarioSeeds[kind] else {
            return StockProjectionScenario(
                kind: kind,
                currentPrice: seed.currentPrice,
                marketCap: seed.marketCap,
                sharesOutstanding: seed.sharesOutstanding,
                years: years
            )
        }

        var previousRevenue = seed.actualRevenue
        var previousNetIncome = seed.actualNetIncome

        for (index, year) in projectionYears.enumerated() {
            let revenueGrowth = scenarioSeed.revenueGrowth[index]
            let revenue = previousRevenue * (1 + revenueGrowth)
            let netMargin = scenarioSeed.netMargin[index]
            let netIncome = revenue * netMargin
            let netIncomeGrowth = previousNetIncome == 0 ? 0 : (netIncome / previousNetIncome) - 1
            let eps = netIncome / seed.sharesOutstanding
            let peLow = scenarioSeed.peLow[index]
            let peHigh = scenarioSeed.peHigh[index]
            let sharePriceLow = eps * peLow
            let sharePriceHigh = eps * peHigh
            let yearsForward = year - actualYear

            years.append(
                StockProjectionYear(
                    year: year,
                    revenue: revenue,
                    revenueGrowth: revenueGrowth,
                    netIncome: netIncome,
                    netIncomeGrowth: netIncomeGrowth,
                    netMargin: netMargin,
                    eps: eps,
                    freeCashFlow: nil,
                    peLowEstimate: peLow,
                    peHighEstimate: peHigh,
                    sharePriceLow: sharePriceLow,
                    sharePriceHigh: sharePriceHigh,
                    cagrLow: cagr(
                        currentPrice: seed.currentPrice,
                        projectedPrice: sharePriceLow,
                        yearsForward: yearsForward
                    ),
                    cagrHigh: cagr(
                        currentPrice: seed.currentPrice,
                        projectedPrice: sharePriceHigh,
                        yearsForward: yearsForward
                    )
                )
            )

            previousRevenue = revenue
            previousNetIncome = netIncome
        }

        return StockProjectionScenario(
            kind: kind,
            currentPrice: seed.currentPrice,
            marketCap: seed.marketCap,
            sharesOutstanding: seed.sharesOutstanding,
            years: years
        )
    }

    private static func cagr(
        currentPrice: Double,
        projectedPrice: Double,
        yearsForward: Int
    ) -> Double? {
        guard currentPrice > 0, projectedPrice > 0, yearsForward > 0 else { return nil }
        return pow(projectedPrice / currentPrice, 1 / Double(yearsForward)) - 1
    }

    private static func projectionSeed(
        revenueGrowth: [Double],
        netMargin: [Double],
        peLow: [Double],
        peHigh: [Double]
    ) -> ProjectionScenarioSeed {
        ProjectionScenarioSeed(
            revenueGrowth: revenueGrowth,
            netMargin: netMargin,
            peLow: peLow,
            peHigh: peHigh
        )
    }

    private static func scenarioSeeds(
        bear: ProjectionScenarioSeed,
        base: ProjectionScenarioSeed,
        bull: ProjectionScenarioSeed
    ) -> [StockProjectionScenarioKind: ProjectionScenarioSeed] {
        [
            .bear: bear,
            .base: base,
            .bull: bull
        ]
    }

    // swiftlint:disable:next function_parameter_count
    private static func metrics(
        ttmPE: Double,
        forwardPE: Double,
        twoYearForwardPE: Double,
        ttmEPSGrowth: Double,
        currentYearExpectedEPSGrowth: Double,
        nextYearEPSGrowth: Double,
        ttmRevenueGrowth: Double,
        currentYearExpectedRevenueGrowth: Double,
        nextYearRevenueGrowth: Double,
        grossMargin: Double,
        netMargin: Double,
        ttmPEGRatio: Double,
        lastYearEPSGrowth: Double,
        ttmVsNTMEPSGrowth: Double,
        currentQuarterEPSGrowthVsPreviousYear: Double,
        twoYearStackExpectedEPSGrowth: Double,
        lastYearRevenueGrowth: Double,
        ttmVsNTMRevenueGrowth: Double,
        currentQuarterRevenueGrowthVsPreviousYear: Double,
        twoYearStackExpectedRevenueGrowth: Double
    ) -> [StockComparisonMetric: Double] {
        [
            .ttmPE: ttmPE,
            .forwardPE: forwardPE,
            .twoYearForwardPE: twoYearForwardPE,
            .ttmEPSGrowth: ttmEPSGrowth,
            .currentYearExpectedEPSGrowth: currentYearExpectedEPSGrowth,
            .nextYearEPSGrowth: nextYearEPSGrowth,
            .ttmRevenueGrowth: ttmRevenueGrowth,
            .currentYearExpectedRevenueGrowth: currentYearExpectedRevenueGrowth,
            .nextYearRevenueGrowth: nextYearRevenueGrowth,
            .grossMargin: grossMargin,
            .netMargin: netMargin,
            .ttmPEGRatio: ttmPEGRatio,
            .lastYearEPSGrowth: lastYearEPSGrowth,
            .ttmVsNTMEPSGrowth: ttmVsNTMEPSGrowth,
            .currentQuarterEPSGrowthVsPreviousYear: currentQuarterEPSGrowthVsPreviousYear,
            .twoYearStackExpectedEPSGrowth: twoYearStackExpectedEPSGrowth,
            .lastYearRevenueGrowth: lastYearRevenueGrowth,
            .ttmVsNTMRevenueGrowth: ttmVsNTMRevenueGrowth,
            .currentQuarterRevenueGrowthVsPreviousYear: currentQuarterRevenueGrowthVsPreviousYear,
            .twoYearStackExpectedRevenueGrowth: twoYearStackExpectedRevenueGrowth
        ]
    }
}

private struct StockInsightSeed {
    let symbol: String
    let companyName: String
    let currentPrice: Double
    let marketCap: Double
    let sharesOutstanding: Double
    let actualRevenue: Double
    let actualNetIncome: Double
    let metrics: [StockComparisonMetric: Double]
    let scenarioSeeds: [StockProjectionScenarioKind: ProjectionScenarioSeed]
}

private struct ProjectionScenarioSeed {
    let revenueGrowth: [Double]
    let netMargin: [Double]
    let peLow: [Double]
    let peHigh: [Double]
}
