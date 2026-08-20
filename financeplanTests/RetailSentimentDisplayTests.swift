@testable import financeplan
import XCTest

@MainActor
final class RetailSentimentDisplayTests: XCTestCase {
    private func sentiment(
        score: Double?,
        label: String = "bullish",
        delta: Double? = nil,
        postCount: Int = 10
    ) -> SymbolSentiment {
        SymbolSentiment(
            symbol: "AAPL",
            asOfDate: "2026-08-20",
            score: score,
            label: label,
            confidence: 0.7,
            postCount: postCount,
            delta1d: delta,
            volumeZ: nil,
            sourceCounts: SentimentSourceCounts(
                x: 5,
                reddit: 3,
                stocktwits: 2,
                news: 0,
                investing: 0,
                seekingAlpha: 0
            ),
            themes: nil
        )
    }

    /// A symbol nobody is posting about carries no score. Rendering that as a
    /// neutral zero would assert a consensus that was never observed.
    func testNilScoreIsAbsenceNotNeutral() {
        let display = RetailSentimentDisplay(sentiment(score: nil, label: "neutral"))

        XCTAssertFalse(display.hasReading)
        XCTAssertEqual(display.label, "No chatter")
        XCTAssertTrue(display.scoreText.isEmpty)
    }

    func testMissingSentimentIsAbsence() {
        XCTAssertFalse(RetailSentimentDisplay(nil).hasReading)
    }

    func testScoreRendersOnHundredScale() {
        let display = RetailSentimentDisplay(sentiment(score: 0.42))

        XCTAssertTrue(display.hasReading)
        XCTAssertEqual(display.label, "Bullish")
        XCTAssertEqual(display.scoreText, "+42")
        XCTAssertEqual(display.postText, "10 posts")
    }

    func testNegativeScoreKeepsSign() {
        let display = RetailSentimentDisplay(sentiment(score: -0.31, label: "bearish"))

        XCTAssertEqual(display.scoreText, "-31")
        XCTAssertEqual(display.label, "Bearish")
    }

    func testTinyDeltasAreSuppressedAsNoise() {
        let display = RetailSentimentDisplay(sentiment(score: 0.4, delta: 0.004))
        XCTAssertNil(display.deltaText)
    }

    func testMeaningfulDeltaIsShownWithDirection() {
        let up = RetailSentimentDisplay(sentiment(score: 0.4, delta: 0.12))
        XCTAssertEqual(up.deltaText, "+0.12")
        XCTAssertTrue(up.deltaUp)

        let down = RetailSentimentDisplay(sentiment(score: -0.2, label: "bearish", delta: -0.25))
        XCTAssertEqual(down.deltaText, "-0.25")
        XCTAssertFalse(down.deltaUp)
    }

    func testPostLabelPluralizes() {
        XCTAssertEqual(RetailSentimentDisplay.postLabel(0), "0 posts")
        XCTAssertEqual(RetailSentimentDisplay.postLabel(1), "1 post")
        XCTAssertEqual(RetailSentimentDisplay.postLabel(42), "42 posts")
    }

    /// The daily pipeline emits positive/negative; the older notable-post path
    /// emits bullish/bearish. Both must colour identically.
    func testColorTreatsSynonymsAlike() {
        XCTAssertEqual(
            RetailSentimentDisplay.color(for: "bullish"),
            RetailSentimentDisplay.color(for: "positive")
        )
        XCTAssertEqual(
            RetailSentimentDisplay.color(for: "bearish"),
            RetailSentimentDisplay.color(for: "negative")
        )
        XCTAssertNotEqual(
            RetailSentimentDisplay.color(for: "bullish"),
            RetailSentimentDisplay.color(for: "neutral")
        )
    }

    func testSourceCountsTotal() {
        let counts = SentimentSourceCounts(
            x: 5,
            reddit: 3,
            stocktwits: 2,
            news: 1,
            investing: 0,
            seekingAlpha: 4
        )
        XCTAssertEqual(counts.total, 15)
    }

    func testSymbolChunkingRespectsServerCap() {
        let symbols = (0 ..< 250).map { "SYM\($0)" }
        let chunks = symbols.chunked(into: InsightsHTTPClient.maxBatchSymbols)

        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0].count, 100)
        XCTAssertEqual(chunks[2].count, 50)
    }

    func testNormalizeUppercasesTrimsAndDeduplicates() {
        let normalized = InsightsHTTPClient.normalize([" aapl ", "AAPL", "msft", "", "  "])
        XCTAssertEqual(normalized, ["AAPL", "MSFT"])
    }
}
