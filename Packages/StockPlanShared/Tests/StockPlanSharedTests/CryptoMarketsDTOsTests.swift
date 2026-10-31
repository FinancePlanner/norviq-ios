import Foundation
import Testing
@testable import StockPlanShared

struct CryptoMarketsDTOsTests {
    @Test(arguments: CryptoMarketsTimeframe.allCases)
    func `timeframe raw values match the query parameter`(_ timeframe: CryptoMarketsTimeframe) {
        let expected: [CryptoMarketsTimeframe: String] = [
            .oneDay: "1d", .oneWeek: "1w", .oneMonth: "1m",
            .yearToDate: "ytd", .oneYear: "1y", .allTime: "all",
        ]
        #expect(timeframe.rawValue == expected[timeframe])
        #expect(!timeframe.displayTitle.isEmpty)
    }

    @Test
    func `returns encode with timeframe keys and read back per timeframe`() throws {
        let returns = CryptoTimeframeReturns(oneDay: 1, oneWeek: 2, oneMonth: 3, yearToDate: 4, oneYear: nil)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(returns)) as? [String: Double]
        #expect(json == ["1d": 1, "1w": 2, "1m": 3, "ytd": 4])

        #expect(returns.value(for: .oneWeek) == 2)
        #expect(returns.value(for: .oneYear) == nil)
        #expect(returns.value(for: .allTime) == nil)
    }

    @Test
    func `response round trips`() throws {
        let coin = CryptoMarketCoin(
            id: "bitcoin", symbol: "BTC", fmpSymbol: "BTCUSD", name: "Bitcoin",
            imageUrl: "https://example.com/btc.png", rank: 1, sector: "Layer 1",
            price: 64000, marketCap: 1.26e12, volume24h: 3.1e10, changePct: 4.2,
            returns: .init(oneDay: 1.1, oneWeek: 4.2, oneMonth: nil, yearToDate: 52, oneYear: 110),
            ath: 73700, athChangePct: -13.1, athDate: "2026-03-14T00:00:00Z",
            atl: 67.8, atlChangePct: 94300, atlDate: "2013-07-06T00:00:00Z",
            sparkline7d: [1, 2, 3]
        )
        let response = CryptoMarketsResponse(
            timeframe: .oneWeek,
            supportedTimeframes: CryptoMarketsTimeframe.allCases,
            source: "coingecko",
            asOf: "2026-10-01T12:00:00Z",
            isStale: false,
            colorMode: .change,
            colorScaleMaxPct: 15,
            attribution: "Data provided by CoinGecko",
            summary: .init(totalMarketCap: 3.1e12, btcDominancePct: 57.2, advancers: 1, decliners: 0),
            coins: [coin],
            gainers: [coin],
            losers: [],
            athBoard: .init(recentAths: [], nearAth: [coin], deepestDrawdowns: [])
        )

        let decoded = try JSONDecoder().decode(CryptoMarketsResponse.self, from: JSONEncoder().encode(response))
        #expect(decoded == response)
    }

    @Test
    func `coin decodes with optional fields absent`() throws {
        let json = Data("""
        {"id":"x","symbol":"X","name":"X Coin","sector":"Other","price":1,
         "returns":{},"sparkline7d":[]}
        """.utf8)
        let coin = try JSONDecoder().decode(CryptoMarketCoin.self, from: json)
        #expect(coin.fmpSymbol == nil)
        #expect(coin.changePct == nil)
        #expect(coin.returns.value(for: .oneDay) == nil)
        #expect(coin.athDate == nil)
    }
}
