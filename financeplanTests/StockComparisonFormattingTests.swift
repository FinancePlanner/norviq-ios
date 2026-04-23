import Foundation
import XCTest
@testable import financeplan

@MainActor
final class StockComparisonFormattingTests: XCTestCase {
    private let enLocale = Locale(identifier: "en_US")
    private let deLocale = Locale(identifier: "de_DE")

    func testPercentFormatting() {
        let value = 0.1563
        XCTAssertEqual(StockMetricFormatter.percentText(value, locale: enLocale), "15.6%")
        
        // German uses comma as decimal separator
        let deResult = StockMetricFormatter.percentText(value, locale: deLocale)
        XCTAssertTrue(deResult == "15,6%" || deResult == "15,6 %")
        
        XCTAssertEqual(StockMetricFormatter.percentText(nil), "—")
    }
    
    func testMultipleFormatting() {
        let value = 24.45
        XCTAssertEqual(StockMetricFormatter.multipleText(value, decimals: 1, locale: enLocale), "24.5x")
        XCTAssertEqual(StockMetricFormatter.multipleText(value, decimals: 1, locale: deLocale), "24,5x")
        XCTAssertEqual(StockMetricFormatter.multipleText(value, decimals: 2, locale: enLocale), "24.45x")
    }
    
    func testCompactCurrencyFormatting() {
        let billions = 1_234_567_890.0
        let millions = 56_700_000.0
        let small = 123.45
        let negative = -1_234_567_890.0
        
        XCTAssertEqual(StockMetricFormatter.compactCurrency(billions, locale: enLocale), "$1.2B")
        XCTAssertEqual(StockMetricFormatter.compactCurrency(millions, locale: enLocale), "$56.7M")
        XCTAssertEqual(StockMetricFormatter.compactCurrency(small, locale: enLocale), "$123.45")
        XCTAssertEqual(StockMetricFormatter.compactCurrency(negative, locale: enLocale), "-$1.2B")
    }
    
    func testCompactNumberFormatting() {
        let billions = 1_234_567_890.0
        let millions = 56_789_000.0
        
        XCTAssertEqual(StockMetricFormatter.compactNumber(billions, locale: enLocale), "1.23B")
        XCTAssertEqual(StockMetricFormatter.compactNumber(millions, locale: enLocale), "56.8M")
    }
    
    func testSignedFormatting() {
        let pos = 123.45
        let neg = -123.45
        
        XCTAssertEqual(StockMetricFormatter.signedCurrencyText(pos, locale: enLocale), "+$123.45")
        XCTAssertEqual(StockMetricFormatter.signedCurrencyText(neg, locale: enLocale), "-$123.45")
        
        XCTAssertEqual(StockMetricFormatter.signedPercentText(0.05, locale: enLocale), "+5.0%")
        XCTAssertEqual(StockMetricFormatter.signedPercentText(-0.05, locale: enLocale), "-5.0%")
    }

    func testMetricGrouping() {
        let mandatoryMetrics = StockComparisonMetricGroup.mandatory.metrics
        XCTAssertTrue(mandatoryMetrics.contains(.ttmPE))
        XCTAssertTrue(mandatoryMetrics.contains(.forwardPE))
        
        let advancedMetrics = StockComparisonMetricGroup.advanced.metrics
        XCTAssertTrue(advancedMetrics.contains(.ttmEPSGrowth))
        XCTAssertTrue(advancedMetrics.contains(.grossMargin))
    }

    func testMetricFormattingMapping() {
        XCTAssertEqual(StockComparisonMetric.ttmPE.format, .multiple)
        XCTAssertEqual(StockComparisonMetric.ttmEPSGrowth.format, .percent)
        XCTAssertEqual(StockComparisonMetric.dcfFairValue.format, .plain)
    }
}
