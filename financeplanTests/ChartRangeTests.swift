import XCTest
@testable import financeplan

@MainActor
final class ChartRangeTests: XCTestCase {
    func testPortfolioRangesMapToTimeRange() {
        for range in ChartRange.portfolio {
            XCTAssertNotNil(PortfolioScreen.TimeRange(range), "\(range)")
        }
        XCTAssertNil(PortfolioScreen.TimeRange(.ytd))
        XCTAssertNil(PortfolioScreen.TimeRange(.fiveYears))
    }

    func testAssetRangesMapToPriceChartRange() {
        for range in ChartRange.asset {
            XCTAssertNotNil(PriceChartRange(range), "\(range)")
        }
        XCTAssertNil(PriceChartRange(.ytd))
        XCTAssertNil(PriceChartRange(.all))
    }

    func testCryptoRangesMapToCryptoChartRange() {
        for range in ChartRange.crypto {
            XCTAssertNotNil(CryptoChartRange(range), "\(range)")
        }
        XCTAssertNil(CryptoChartRange(.fiveYears))
    }

    func testWireValuesAreUnchanged() {
        XCTAssertEqual(PriceChartRange(.oneWeek)?.rawValue, "1W")
        XCTAssertEqual(PortfolioScreen.TimeRange(.all)?.rawValue, "ALL")
        XCTAssertEqual(CryptoChartRange(.all), .allTime)
    }

    func testReverseMappingRoundTrips() {
        for range in ChartRange.asset {
            XCTAssertEqual(PriceChartRange(range).flatMap(ChartRange.init), range)
        }
        for range in ChartRange.crypto {
            XCTAssertEqual(CryptoChartRange(range).flatMap(ChartRange.init), range)
        }
        for range in ChartRange.portfolio {
            XCTAssertEqual(PortfolioScreen.TimeRange(range).flatMap(ChartRange.init), range)
        }
        XCTAssertNil(ChartRange(PriceChartRange.oneHour))
        XCTAssertNil(ChartRange(CryptoChartRange.hour))
    }

    func testDisplayVocabulary() {
        XCTAssertEqual(
            ChartRange.allCases.map(\.title),
            ["1D", "1W", "1M", "3M", "YTD", "1Y", "5Y", "ALL"]
        )
    }
}
