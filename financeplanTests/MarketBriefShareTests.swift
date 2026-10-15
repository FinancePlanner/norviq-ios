import StockPlanShared
import SwiftUI
import XCTest
@testable import financeplan

private enum ShareFixtures {
  static func morning(
    language: String = "en",
    items: [MarketBriefItem]? = nil,
    greeting: String? = "Good morning. Europe opens lower."
  ) -> MarketBriefResponse {
    let portuguese = language == "pt-PT"
    return MarketBriefResponse(
      enabled: true,
      tradingDate: "2026-10-15",
      slot: .morning,
      language: language,
      greeting: greeting,
      groups: [
        MarketBriefQuoteGroup(id: "eu_open", title: portuguese ? "Abertura europeia negativa" : "European open lower", tone: .down, rows: [
          MarketBriefQuoteRow(symbol: "^GDAXI", flag: "🇩🇪", name: "DAX", level: portuguese ? "25.032" : "25,032", changePercent: portuguese ? "0,77%" : "0.77%", direction: .down),
          MarketBriefQuoteRow(symbol: "^FCHI", flag: "🇫🇷", name: "CAC 40", level: portuguese ? "8.104" : "8,104", changePercent: portuguese ? "0,41%" : "0.41%", direction: .down),
          MarketBriefQuoteRow(symbol: "^STOXX50E", flag: "🇪🇺", name: "Euro Stoxx 50", level: portuguese ? "5.611" : "5,611", changePercent: portuguese ? "0,12%" : "0.12%", direction: .up)
        ]),
        MarketBriefQuoteGroup(id: "us_futures", title: portuguese ? "Futuros americanos mistos" : "US futures mixed", tone: .flat, rows: [
          MarketBriefQuoteRow(symbol: "NQ=F", flag: "🇺🇸", name: portuguese ? "Futuros Nasdaq 100" : "Nasdaq 100 futures", level: portuguese ? "25.410" : "25,410", changePercent: portuguese ? "0,20%" : "0.20%", direction: .down),
          MarketBriefQuoteRow(symbol: "ES=F", flag: "🇺🇸", name: portuguese ? "Futuros S&P 500" : "S&P 500 futures", level: portuguese ? "6.702" : "6,702", changePercent: portuguese ? "0,00%" : "0.00%", direction: .flat)
        ])
      ],
      items: items ?? [
        MarketBriefItem(
          kind: .highlight,
          text: portuguese
            ? "Fabricantes de chips recuam após previsões fracas de um fornecedor-chave."
            : "Chipmakers slip after a weak outlook from a key supplier.",
          tickers: ["asml", "NVDA"],
          sourceUrl: "https://www.reuters.com/markets/"
        ),
        MarketBriefItem(
          kind: .highlight,
          text: portuguese
            ? "O petróleo sobe com tensões no Médio Oriente; energia lidera na Europa."
            : "Oil climbs on Middle East tension; energy leads Europe.",
          tickers: ["NVDA", "BRK.B", "XOM"],
          sourceUrl: nil
        ),
        MarketBriefItem(kind: .earnings, text: portuguese ? "Apresenta resultados antes da abertura." : "Reporting today before the open.", tickers: ["JPM", "TSLA"], sourceUrl: nil),
        MarketBriefItem(kind: .highlight, text: "Fourth item, never quoted.", tickers: [], sourceUrl: nil)
      ],
      generatedAt: "2026-10-15T07:16:00Z",
      degraded: false
    )
  }

  static func evening(language: String = "en") -> MarketBriefResponse {
    MarketBriefResponse(
      enabled: true,
      tradingDate: "2026-10-14",
      slot: .evening,
      language: language,
      greeting: nil,
      groups: [],
      items: [
        MarketBriefItem(kind: .story, text: "Banks lead the S&P 500 higher on strong trading revenue.", tickers: ["GS"], sourceUrl: nil),
        MarketBriefItem(kind: .story, text: "Oil falls as\ninventories build.", tickers: [], sourceUrl: nil)
      ],
      generatedAt: "2026-10-14T21:31:00Z",
      degraded: false
    )
  }

  static func payload(_ brief: MarketBriefResponse = morning()) throws -> MarketBriefSharePayload {
    try XCTUnwrap(MarketBriefSharePayload(brief: brief))
  }
}

private func queryValue(_ name: String, in url: URL) -> String? {
  URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
}

// MARK: - Payload

final class MarketBriefSharePayloadTests: XCTestCase {
  func testNoPayloadWithoutSlotOrWellFormedDate() {
    XCTAssertNil(MarketBriefSharePayload(brief: .empty(language: "en", enabled: true)))
    let badDate = MarketBriefResponse(
      enabled: true, tradingDate: "15/10/2026", slot: .morning, language: "en",
      greeting: nil, groups: [], items: [], generatedAt: nil, degraded: false
    )
    XCTAssertNil(MarketBriefSharePayload(brief: badDate))
  }

  func testEnglishPermalinkHasNoQuery() throws {
    let payload = try ShareFixtures.payload()
    XCTAssertEqual(payload.permalink().absoluteString, "https://www.norviq.org/brief/2026-10-15/morning")
    XCTAssertEqual(
      try ShareFixtures.payload(ShareFixtures.evening()).permalink().absoluteString,
      "https://www.norviq.org/brief/2026-10-14/evening"
    )
  }

  func testPortuguesePermalinkCarriesLang() throws {
    let payload = try ShareFixtures.payload(ShareFixtures.morning(language: "pt-PT"))
    XCTAssertEqual(payload.permalink().absoluteString, "https://www.norviq.org/brief/2026-10-15/morning?lang=pt-PT")
  }

  func testChannelPermalinksAddUTMAndKeepLang() throws {
    let english = try ShareFixtures.payload()
    XCTAssertEqual(
      english.permalink(for: .x).absoluteString,
      "https://www.norviq.org/brief/2026-10-15/morning?utm_source=x&utm_medium=share"
    )
    XCTAssertEqual(
      english.permalink(for: .copyLink).absoluteString,
      "https://www.norviq.org/brief/2026-10-15/morning?utm_source=copy_link&utm_medium=share"
    )
    let portuguese = try ShareFixtures.payload(ShareFixtures.morning(language: "pt-PT"))
    XCTAssertEqual(
      portuguese.permalink(for: .whatsapp).absoluteString,
      "https://www.norviq.org/brief/2026-10-15/morning?lang=pt-PT&utm_source=whatsapp&utm_medium=share"
    )
    for channel in MarketBriefShareChannel.allCases {
      let url = portuguese.permalink(for: channel)
      XCTAssertEqual(queryValue("utm_source", in: url), channel.rawValue)
      XCTAssertEqual(queryValue("utm_medium", in: url), "share")
      XCTAssertEqual(queryValue("lang", in: url), "pt-PT")
    }
  }

  func testTitlesAndDisclaimerFollowTheBriefLanguage() throws {
    let english = try ShareFixtures.payload()
    let dateEN = try XCTUnwrap(MarketBriefFormat.tradingDateLabel("2026-10-15", language: "en"))
    XCTAssertEqual(english.title, "Morning brief · \(dateEN)")
    XCTAssertEqual(english.disclaimer, "AI-written from market data. Not financial advice.")
    XCTAssertEqual(try ShareFixtures.payload(ShareFixtures.evening()).slotTitle, "Market close recap")

    let portuguese = try ShareFixtures.payload(ShareFixtures.morning(language: "pt-PT"))
    let datePT = try XCTUnwrap(MarketBriefFormat.tradingDateLabel("2026-10-15", language: "pt-PT"))
    XCTAssertEqual(portuguese.title, "Briefing da manhã · \(datePT)")
    XCTAssertEqual(
      portuguese.disclaimer,
      "Escrito por IA a partir de dados de mercado. Não constitui aconselhamento financeiro."
    )
    XCTAssertEqual(try ShareFixtures.payload(ShareFixtures.evening(language: "pt-PT")).slotTitle, "Resumo do fecho")
  }

  func testHeadlineIsFirstItemElseGreeting() throws {
    XCTAssertEqual(try ShareFixtures.payload().headline, "Chipmakers slip after a weak outlook from a key supplier.")
    let noItems = try ShareFixtures.payload(ShareFixtures.morning(items: []))
    XCTAssertEqual(noItems.headline, "Good morning. Europe opens lower.")
    XCTAssertNil(try ShareFixtures.payload(ShareFixtures.morning(items: [], greeting: "  ")).headline)
  }

  func testLinkMessageIsTitleAndHeadline() throws {
    let payload = try ShareFixtures.payload()
    XCTAssertEqual(payload.linkMessage, "\(payload.title)\nChipmakers slip after a weak outlook from a key supplier.")
    XCTAssertTrue(payload.imageMessage.hasSuffix("?utm_source=image&utm_medium=share"))
  }

  func testCashtagsInOrderWithoutDuplicatesAtMostThreeLettersOnly() throws {
    // asml, NVDA | NVDA, BRK.B, XOM | JPM, TSLA
    XCTAssertEqual(try ShareFixtures.payload().cashtags, ["$ASML", "$NVDA", "$XOM"])
    XCTAssertEqual(try ShareFixtures.payload(ShareFixtures.evening()).cashtags, ["$GS"])
    XCTAssertEqual(try ShareFixtures.payload(ShareFixtures.morning(items: [])).cashtags, [])
  }

  func testXTextHasTitleHeadlineCashtagsAndPermalink() throws {
    let payload = try ShareFixtures.payload()
    let lines = payload.xText.components(separatedBy: "\n")
    XCTAssertEqual(lines, [
      payload.title,
      "Chipmakers slip after a weak outlook from a key supplier.",
      "$ASML $NVDA $XOM",
      "https://www.norviq.org/brief/2026-10-15/morning?utm_source=x&utm_medium=share"
    ])
    XCTAssertLessThanOrEqual(payload.xText.count, 280)
  }

  func testXTextShortensALongHeadlineAndKeepsTheLink() throws {
    let long = String(repeating: "Markets wobble as traders weigh rate cuts. ", count: 12)
    let brief = ShareFixtures.morning(
      language: "pt-PT",
      items: [MarketBriefItem(kind: .highlight, text: long, tickers: ["NVDA", "AMD", "INTC", "TSM"], sourceUrl: nil)]
    )
    let payload = try ShareFixtures.payload(brief)
    let text = payload.xText
    XCTAssertLessThanOrEqual(text.count, 280)
    XCTAssertTrue(text.hasPrefix(payload.title + "\n"))
    XCTAssertTrue(text.contains("…"))
    XCTAssertTrue(text.contains("$NVDA $AMD $INTC"))
    XCTAssertFalse(text.contains("$TSM"))
    XCTAssertTrue(text.hasSuffix(payload.permalink(for: .x).absoluteString))
  }

  func testXIntentURLCarriesTheWholeTextIncludingAmpersands() throws {
    let brief = ShareFixtures.morning(items: [
      MarketBriefItem(kind: .highlight, text: "S&P 500 = record? Yes + more", tickers: ["SPY"], sourceUrl: nil)
    ])
    let payload = try ShareFixtures.payload(brief)
    let url = try XCTUnwrap(payload.xIntentURL)
    XCTAssertEqual(url.host(), "x.com")
    XCTAssertEqual(url.path(), "/intent/tweet")
    let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    XCTAssertEqual(items.map(\.name), ["text"])
    XCTAssertEqual(items.first?.value, payload.xText)
    XCTAssertTrue(url.absoluteString.contains("S%26P%20500%20%3D%20record%3F%20Yes%20%2B%20more"))
  }

  func testRedditURLEncodesPermalinkAndTitle() throws {
    let payload = try ShareFixtures.payload(ShareFixtures.morning(language: "pt-PT"))
    let url = try XCTUnwrap(payload.redditURL)
    XCTAssertEqual(url.host(), "www.reddit.com")
    XCTAssertEqual(url.path(), "/submit")
    XCTAssertEqual(queryValue("url", in: url), payload.permalink(for: .reddit).absoluteString)
    XCTAssertEqual(queryValue("title", in: url), payload.title)
    XCTAssertTrue(url.absoluteString.hasPrefix(
      "https://www.reddit.com/submit?url=https%3A%2F%2Fwww.norviq.org%2Fbrief%2F2026-10-15%2Fmorning%3Flang%3Dpt-PT%26utm_source%3Dreddit%26utm_medium%3Dshare&title=Briefing%20da%20manh%C3%A3%20%C2%B7%20"
    ))
  }

  func testWhatsAppURLCarriesTextAndPermalink() throws {
    let payload = try ShareFixtures.payload()
    let url = try XCTUnwrap(payload.whatsAppURL)
    XCTAssertEqual(url.host(), "wa.me")
    XCTAssertEqual(queryValue("text", in: url), payload.whatsAppText)
    XCTAssertEqual(payload.whatsAppText, [
      payload.title,
      "Chipmakers slip after a weak outlook from a key supplier.",
      "https://www.norviq.org/brief/2026-10-15/morning?utm_source=whatsapp&utm_medium=share"
    ].joined(separator: "\n"))
  }

  func testDiscordMarkdownHasIndexesTopItemsPermalinkAndDisclaimer() throws {
    let payload = try ShareFixtures.payload()
    let markdown = payload.discordMarkdown
    XCTAssertTrue(markdown.hasPrefix("**\(payload.title)**\n"))
    XCTAssertTrue(markdown.contains("__European open lower__\n🇩🇪 DAX 25,032 ▼ 0.77%"))
    XCTAssertTrue(markdown.contains("🇪🇺 Euro Stoxx 50 5,611 ▲ 0.12%"))
    XCTAssertTrue(markdown.contains("🇺🇸 S&P 500 futures 6,702 – 0.00%"))
    XCTAssertTrue(markdown.contains("📌 Chipmakers slip after a weak outlook from a key supplier."))
    XCTAssertTrue(markdown.contains("📍 Reporting today before the open."))
    XCTAssertFalse(markdown.contains("Fourth item"))
    XCTAssertTrue(markdown.hasSuffix(
      "https://www.norviq.org/brief/2026-10-15/morning?utm_source=discord&utm_medium=share\n_AI-written from market data. Not financial advice._"
    ))
    XCTAssertLessThan(markdown.count, 2_000)
  }

  func testDiscordNumbersEveningStoriesOnOneLineEach() throws {
    let markdown = try ShareFixtures.payload(ShareFixtures.evening(language: "pt-PT")).discordMarkdown
    XCTAssertTrue(markdown.contains("\n1. Banks lead the S&P 500 higher on strong trading revenue.\n2. Oil falls as inventories build.\n"))
    XCTAssertTrue(markdown.contains("?lang=pt-PT&utm_source=discord&utm_medium=share"))
    XCTAssertTrue(markdown.hasSuffix("_Escrito por IA a partir de dados de mercado. Não constitui aconselhamento financeiro._"))
  }

  func testQueryEncodingEscapesReservedCharacters() {
    XCTAssertEqual(MarketBriefSharePayload.queryEncoded("a&b=c?d+e f/é#"), "a%26b%3Dc%3Fd%2Be%20f%2F%C3%A9%23")
    XCTAssertEqual(MarketBriefSharePayload.queryEncoded("A-z_0.9~"), "A-z_0.9~")
  }
}

// MARK: - Analytics

final class MarketBriefShareTelemetryTests: XCTestCase {
  @MainActor
  func testSharedEventCarriesChannelSlotDateLangAndSurface() throws {
    let payload = try ShareFixtures.payload(ShareFixtures.evening(language: "pt-PT"))
    var captured: [(String, [String: Any])] = []
    let telemetry = MarketBriefShareTelemetry { captured.append(($0, $1)) }

    telemetry.shared(payload, channel: .whatsapp)

    XCTAssertEqual(captured.count, 1)
    XCTAssertEqual(captured.first?.0, "market_brief_shared")
    XCTAssertEqual(captured.first?.1 as? [String: String], [
      "channel": "whatsapp",
      "slot": "evening",
      "date": "2026-10-14",
      "lang": "pt-PT",
      "surface": "card"
    ])
  }

  func testChannelNamesAreStable() {
    XCTAssertEqual(
      MarketBriefShareChannel.allCases.map(\.rawValue),
      ["link", "image", "x", "reddit", "whatsapp", "discord", "copy_link"]
    )
  }
}

// MARK: - Share card

@MainActor
final class MarketBriefShareCardTests: XCTestCase {
  func testRendersAtShareSizeInLightSchemeForBothLanguages() throws {
    let briefs: [(String, MarketBriefResponse)] = [
      ("en", ShareFixtures.morning()),
      ("pt", ShareFixtures.morning(language: "pt-PT")),
      ("evening-en", ShareFixtures.evening())
    ]
    for (name, brief) in briefs {
      let card = MarketBriefShareCard(payload: try ShareFixtures.payload(brief))
        // The card must stay light even when the phone is in dark mode.
        .environment(\.colorScheme, .dark)
      let image = try XCTUnwrap(
        ChartExporter.exportToImage(card, size: MarketBriefShareCard.size, scale: 1),
        name
      )
      XCTAssertEqual(image.size.width, 1080, accuracy: 1, name)
      XCTAssertEqual(image.size.height, 1350, accuracy: 1, name)
      let corner = try XCTUnwrap(Self.pixel(of: image, x: 4, y: 4), name)
      XCTAssertGreaterThan(corner.red, 0.95, name)
      XCTAssertGreaterThan(corner.green, 0.95, name)
      XCTAssertGreaterThan(corner.blue, 0.95, name)

      // Optional artifacts for eyeballing; the simulator shares the host filesystem.
      if let directory = ProcessInfo.processInfo.environment["MARKET_BRIEF_CARD_PREVIEW_DIR"] {
        let url = URL(fileURLWithPath: directory).appendingPathComponent("ios-brief-card-\(name).png")
        try image.pngData()?.write(to: url)
      }
    }
  }

  private static func pixel(of image: UIImage, x: Int, y: Int) -> (red: Double, green: Double, blue: Double)? {
    guard let cgImage = image.cgImage?.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else { return nil }
    var bytes = [UInt8](repeating: 0, count: 4)
    let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
      guard let context = CGContext(
        data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else { return false }
      context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
      return true
    }
    guard drawn else { return nil }
    return (Double(bytes[0]) / 255, Double(bytes[1]) / 255, Double(bytes[2]) / 255)
  }
}
