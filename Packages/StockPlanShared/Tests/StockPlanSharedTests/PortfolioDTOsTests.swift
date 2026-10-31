import Foundation
import Testing
@testable import StockPlanShared

@Suite("Portfolio DTOs")
struct PortfolioDTOsTests {
    // MARK: - PortfolioSummaryResponse Tests

    @Test
    func portfolioSummaryResponseFullRoundTrip() throws {
        let original = PortfolioSummaryResponse(
            baseCurrency: "USD",
            totalValue: 100_000.0,
            totalCost: 90000.0,
            unrealizedPnl: 10000.0,
            realizedPnl: 5000.0,
            cashBalance: 15000.0,
            allocation: [
                AllocationItem(symbol: "AAPL", value: 40000.0, currency: "USD"),
                AllocationItem(symbol: "GOOGL", value: 60000.0, currency: "USD"),
            ],
            dayChange: 250.0,
            dayChangePercent: 0.25,
            unrealizedPnlPercent: 10.0,
            asOf: "2024-07-11T16:30:00Z"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PortfolioSummaryResponse.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.dayChange == 250.0)
        #expect(decoded.dayChangePercent == 0.25)
        #expect(decoded.unrealizedPnlPercent == 10.0)
        #expect(decoded.asOf == "2024-07-11T16:30:00Z")
    }

    @Test
    func portfolioSummaryResponseLegacyDecode() throws {
        let legacyJSON = """
        {
            "baseCurrency": "USD",
            "totalValue": 100000.0,
            "totalCost": 90000.0,
            "unrealizedPnl": 10000.0,
            "realizedPnl": 5000.0,
            "allocation": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PortfolioSummaryResponse.self, from: legacyJSON)

        #expect(decoded.baseCurrency == "USD")
        #expect(decoded.totalValue == 100_000.0)
        #expect(decoded.dayChange == nil)
        #expect(decoded.dayChangePercent == nil)
        #expect(decoded.unrealizedPnlPercent == nil)
        #expect(decoded.asOf == nil)
        #expect(decoded.cashBalance == 0) // default when omitted
    }

    @Test
    func portfolioSummaryResponseLegacyDecodeWithCashBalance() throws {
        let legacyJSON = """
        {
            "baseCurrency": "USD",
            "totalValue": 100000.0,
            "totalCost": 90000.0,
            "unrealizedPnl": 10000.0,
            "realizedPnl": 5000.0,
            "cashBalance": 25000.0,
            "allocation": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PortfolioSummaryResponse.self, from: legacyJSON)

        #expect(decoded.cashBalance == 25000.0)
        #expect(decoded.dayChange == nil)
    }

    // MARK: - PnlBySymbol Tests

    @Test
    func pnlBySymbolFullRoundTrip() throws {
        let original = PnlBySymbol(
            symbol: "AAPL",
            currency: "USD",
            realizedPnl: 500.0,
            unrealizedPnl: 1000.0,
            shares: 10.0,
            buyPrice: 150.0,
            costBasis: 1500.0,
            currentPrice: 175.0,
            marketValue: 1750.0,
            unrealizedPnlPercent: 16.67,
            dayChange: 25.0,
            dayChangePercent: 1.43
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PnlBySymbol.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.shares == 10.0)
        #expect(decoded.buyPrice == 150.0)
        #expect(decoded.costBasis == 1500.0)
        #expect(decoded.currentPrice == 175.0)
        #expect(decoded.marketValue == 1750.0)
        #expect(decoded.unrealizedPnlPercent == 16.67)
        #expect(decoded.dayChange == 25.0)
        #expect(decoded.dayChangePercent == 1.43)
    }

    @Test
    func pnlBySymbolLegacyDecode() throws {
        let legacyJSON = """
        {
            "symbol": "AAPL",
            "currency": "USD",
            "realizedPnl": 500.0,
            "unrealizedPnl": 1000.0
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PnlBySymbol.self, from: legacyJSON)

        #expect(decoded.symbol == "AAPL")
        #expect(decoded.currency == "USD")
        #expect(decoded.realizedPnl == 500.0)
        #expect(decoded.unrealizedPnl == 1000.0)
        #expect(decoded.shares == nil)
        #expect(decoded.buyPrice == nil)
        #expect(decoded.costBasis == nil)
        #expect(decoded.currentPrice == nil)
        #expect(decoded.marketValue == nil)
        #expect(decoded.unrealizedPnlPercent == nil)
        #expect(decoded.dayChange == nil)
        #expect(decoded.dayChangePercent == nil)
    }

    @Test
    func pnlBySymbolPartialDecode() throws {
        let partialJSON = """
        {
            "symbol": "GOOGL",
            "currency": "USD",
            "realizedPnl": 200.0,
            "unrealizedPnl": 800.0,
            "shares": 5.0,
            "marketValue": 2500.0
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PnlBySymbol.self, from: partialJSON)

        #expect(decoded.shares == 5.0)
        #expect(decoded.marketValue == 2500.0)
        #expect(decoded.buyPrice == nil)
        #expect(decoded.currentPrice == nil)
    }

    // MARK: - PortfolioPerformanceResponse Tests

    @Test
    func portfolioPerformanceResponseFullRoundTrip() throws {
        let points = [
            PerformancePoint(date: "2024-01-01", value: 10000.0),
            PerformancePoint(date: "2024-01-02", value: 10250.0),
            PerformancePoint(date: "2024-01-03", value: 10100.0),
        ]

        let original = PortfolioPerformanceResponse(
            baseCurrency: "USD",
            points: points,
            range: "1D"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PortfolioPerformanceResponse.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.baseCurrency == "USD")
        #expect(decoded.points.count == 3)
        #expect(decoded.range == "1D")
    }

    @Test
    func portfolioPerformanceResponseLegacyDecode() throws {
        let legacyJSON = """
        {
            "baseCurrency": "USD",
            "points": [
                {"date": "2024-01-01", "value": 10000.0},
                {"date": "2024-01-02", "value": 10250.0}
            ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PortfolioPerformanceResponse.self, from: legacyJSON)

        #expect(decoded.baseCurrency == "USD")
        #expect(decoded.points.count == 2)
        #expect(decoded.range == nil)
    }

    @Test
    func portfolioPerformanceResponseWithRange() throws {
        let legacyJSON = """
        {
            "baseCurrency": "USD",
            "points": [],
            "range": "1Y"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PortfolioPerformanceResponse.self, from: legacyJSON)

        #expect(decoded.range == "1Y")
    }

    // MARK: - PortfolioChange Tests

    @Test
    func portfolioChangeFullRoundTrip() throws {
        let original = PortfolioChange(
            percent: -0.004,
            absolute: -42.5,
            fromDate: "2024-01-02",
            toDate: "2024-01-03",
            basis: PortfolioChange.Basis.previousTradingDay
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PortfolioChange.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.percent == -0.004)
        #expect(decoded.absolute == -42.5)
        #expect(decoded.basis == "previousTradingDay")
    }

    /// A basis value this client has never heard of must decode, not throw.
    /// The server is free to add one without stranding pinned clients.
    @Test
    func portfolioChangeDecodesUnknownBasis() throws {
        let json = """
        {
            "percent": 0.01,
            "absolute": 10.0,
            "fromDate": "2024-01-01",
            "toDate": "2024-01-02",
            "basis": "sinceSomeFutureThing"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PortfolioChange.self, from: json)

        #expect(decoded.basis == "sinceSomeFutureThing")
    }

    // MARK: - PortfolioChanges Tests

    /// The core guarantee of the contract: a change the server could not compute
    /// is ABSENT, and must stay absent through decoding. A nil here is what tells
    /// the UI to render an empty state; a zero would read as "flat" and would be
    /// a lie of exactly the kind this field exists to prevent.
    @Test
    func portfolioChangesOmittedMembersDecodeAsNilNotZero() throws {
        let json = """
        {
            "day": {
                "percent": -0.004,
                "absolute": -42.5,
                "fromDate": "2024-01-02",
                "toDate": "2024-01-03",
                "basis": "previousTradingDay"
            }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PortfolioChanges.self, from: json)

        #expect(decoded.day?.percent == -0.004)
        #expect(decoded.week == nil)
        #expect(decoded.month == nil)
        #expect(decoded.ytd == nil)
        #expect(decoded.sinceInception == nil)
    }

    @Test
    func portfolioChangesFullRoundTrip() throws {
        func change(_ basis: String) -> PortfolioChange {
            PortfolioChange(
                percent: 0.05,
                absolute: 500.0,
                fromDate: "2024-01-01",
                toDate: "2024-01-31",
                basis: basis
            )
        }

        let original = PortfolioChanges(
            day: change(PortfolioChange.Basis.previousTradingDay),
            week: change(PortfolioChange.Basis.week),
            month: change(PortfolioChange.Basis.month),
            ytd: change(PortfolioChange.Basis.ytd),
            sinceInception: change(PortfolioChange.Basis.inception)
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PortfolioChanges.self, from: encoded)

        #expect(decoded == original)
    }

    // MARK: - PerformancePoint provenance

    @Test
    func performancePointCarriesCostBasisAndSource() throws {
        let original = PerformancePoint(
            date: "2024-01-03",
            value: 10100.0,
            costBasis: 9000.0,
            source: PerformancePoint.Source.backfill
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PerformancePoint.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.costBasis == 9000.0)
        #expect(decoded.source == "backfill")
    }

    /// Points from a backend older than this contract carry neither field.
    @Test
    func performancePointLegacyDecode() throws {
        let legacyJSON = """
        {"date": "2024-01-01", "value": 10000.0}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PerformancePoint.self, from: legacyJSON)

        #expect(decoded.value == 10000.0)
        #expect(decoded.costBasis == nil)
        #expect(decoded.source == nil)
    }

    // MARK: - PortfolioPerformanceResponse with changes

    @Test
    func portfolioPerformanceResponseCarriesChanges() throws {
        let original = PortfolioPerformanceResponse(
            baseCurrency: "USD",
            points: [PerformancePoint(date: "2024-01-03", value: 10100.0)],
            range: "1M",
            asOf: "2024-01-03",
            changes: PortfolioChanges(
                day: PortfolioChange(
                    percent: -0.004,
                    absolute: -42.5,
                    fromDate: "2024-01-02",
                    toDate: "2024-01-03",
                    basis: PortfolioChange.Basis.previousTradingDay
                )
            )
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PortfolioPerformanceResponse.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.asOf == "2024-01-03")
        #expect(decoded.changes?.day?.basis == "previousTradingDay")
        #expect(decoded.changes?.ytd == nil)
    }

    /// A response from a backend that has no history yet: points may exist while
    /// every change is absent. Clients must not read that as a flat portfolio.
    @Test
    func portfolioPerformanceResponseWithoutChangesDecodes() throws {
        let json = """
        {
            "baseCurrency": "USD",
            "points": [{"date": "2024-01-01", "value": 10000.0}]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PortfolioPerformanceResponse.self, from: json)

        #expect(decoded.points.count == 1)
        #expect(decoded.changes == nil)
        #expect(decoded.asOf == nil)
    }
}
