#if DEBUG
import StockPlanShared
import SwiftUI

/// Canned briefs for the canvas; never talks to the network.
private struct PreviewMarketBriefService: MarketBriefServicing {
  func brief(language: String, slot: MarketBriefSlot?, date: String?) async throws -> MarketBriefResponse {
    slot == .evening ? Self.evening : Self.morning
  }

  func notificationPreferences() async throws -> MarketBriefNotificationPreferences {
    MarketBriefNotificationPreferences(enabled: false, language: "en")
  }

  func updateNotificationPreferences(enabled: Bool, language: String) async throws -> MarketBriefNotificationPreferences {
    MarketBriefNotificationPreferences(enabled: enabled, language: language)
  }

  static let morning = MarketBriefResponse(
    enabled: true,
    tradingDate: "2026-10-15",
    slot: .morning,
    language: "en",
    greeting: "Good morning. Europe opens lower and US futures point to a soft start.",
    groups: [
      MarketBriefQuoteGroup(id: "eu_open", title: "European open lower", tone: .down, rows: [
        MarketBriefQuoteRow(symbol: "^GDAXI", flag: "🇩🇪", name: "DAX", level: "25,032", changePercent: "0.77%", direction: .down),
        MarketBriefQuoteRow(symbol: "^FCHI", flag: "🇫🇷", name: "CAC 40", level: "8,104", changePercent: "0.41%", direction: .down),
        MarketBriefQuoteRow(symbol: "^STOXX50E", flag: "🇪🇺", name: "Euro Stoxx 50", level: "5,611", changePercent: "0.12%", direction: .up)
      ]),
      MarketBriefQuoteGroup(id: "us_futures", title: "US futures mixed", tone: .flat, rows: [
        MarketBriefQuoteRow(symbol: "NQ=F", flag: "🇺🇸", name: "Nasdaq 100 futures", level: "25,410", changePercent: "0.20%", direction: .down),
        MarketBriefQuoteRow(symbol: "ES=F", flag: "🇺🇸", name: "S&P 500 futures", level: "6,702", changePercent: "0.00%", direction: .flat)
      ])
    ],
    items: [
      MarketBriefItem(kind: .highlight, text: "Chipmakers slip after a weak outlook from a key supplier.", tickers: ["ASML", "NVDA"], sourceUrl: "https://www.reuters.com/markets/"),
      MarketBriefItem(kind: .earnings, text: "Reporting today before the open.", tickers: ["JPM"], sourceUrl: nil)
    ],
    generatedAt: "2026-10-15T07:16:00Z",
    degraded: true,
    previous: MarketBriefRef(slot: .evening, tradingDate: "2026-10-14")
  )

  static let evening = MarketBriefResponse(
    enabled: true,
    tradingDate: "2026-10-14",
    slot: .evening,
    language: "en",
    greeting: nil,
    groups: [],
    items: [
      MarketBriefItem(kind: .story, text: "Banks lead the S&P 500 higher on strong trading revenue.", tickers: ["GS"], sourceUrl: "https://www.cnbc.com/x"),
      MarketBriefItem(kind: .story, text: "Oil falls as inventories build.", tickers: [], sourceUrl: nil)
    ],
    generatedAt: "2026-10-14T21:31:00Z",
    degraded: false
  )
}

private struct MarketBriefCardPreview: View {
  @State private var viewModel = MarketBriefViewModel(
    language: "en",
    service: PreviewMarketBriefService(),
    cache: MarketBriefCache(directory: nil)
  )

  var body: some View {
    ScrollView {
      MarketBriefCard(viewModel: viewModel)
        .padding(16)
    }
    .task { await viewModel.loadIfNeeded() }
  }
}

#Preview("Market brief") {
  MarketBriefCardPreview()
}
#endif
