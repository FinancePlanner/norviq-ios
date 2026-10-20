import Algorithms
import Foundation
import StockPlanShared

/// Everything a shared market brief says, per channel: the permalink the web
/// serves, the title, and the prefilled text and intent URLs. Pure and written
/// in the brief's own language (not the app's), so it is unit-tested.
nonisolated struct MarketBriefSharePayload: Equatable, Sendable {
  /// The web app that serves `/brief/{date}/{slot}`.
  static let webBaseURL = URL(string: "https://www.norviq.org")!
  /// X counts every link as 23 characters; this budget counts the full URL,
  /// so a post that fits here always fits on X.
  static let xCharacterLimit = 280
  static let maxCashtags = 3
  /// Items quoted in Discord and on the image.
  static let maxItems = 3

  let brief: MarketBriefResponse
  let slot: MarketBriefSlot
  /// `yyyy-MM-dd`, Lisbon.
  let tradingDate: String
  let isPortuguese: Bool
  private let baseURL: URL

  /// Nil for a brief without a slot or a well-formed date: there is no page to link to.
  init?(brief: MarketBriefResponse, baseURL: URL = Self.webBaseURL) {
    guard let slot = brief.slot,
          let tradingDate = brief.tradingDate,
          MarketBriefDeepLink.isTradingDate(tradingDate)
    else { return nil }
    self.brief = brief
    self.slot = slot
    self.tradingDate = tradingDate
    isPortuguese = brief.language.lowercased().hasPrefix("pt")
    self.baseURL = baseURL
  }

  // MARK: Text

  /// `en` or `pt-PT`, the brief's language as the web's `lang` parameter takes it.
  var languageCode: String { isPortuguese ? "pt-PT" : "en" }

  var slotTitle: String {
    switch slot {
    case .morning: localized(en: "Morning brief", pt: "Briefing da manhã")
    case .evening: localized(en: "Market close recap", pt: "Resumo do fecho")
    }
  }

  /// "Thu, Oct 15" / "qui., 15/10"; the raw date if it cannot be formatted.
  var dateLabel: String {
    MarketBriefFormat.tradingDateLabel(tradingDate, language: languageCode) ?? tradingDate
  }

  /// "Morning brief · Thu, Oct 15".
  var title: String { "\(slotTitle) · \(dateLabel)" }

  /// The first item, else the greeting, on one line.
  var headline: String? {
    let candidates = [brief.items.first?.text, brief.greeting]
    return candidates.lazy
      .compactMap { $0.map(Self.singleLine) }
      .first { !$0.isEmpty }
  }

  /// `$NVDA $ASML`: the brief's tickers in order of appearance, without
  /// duplicates, keeping only symbols X turns into cashtags (1–6 letters).
  var cashtags: [String] {
    brief.items.flatMap(\.tickers)
      .map { $0.uppercased() }
      .filter(Self.isCashtagSymbol)
      .uniqued()
      .prefix(Self.maxCashtags)
      .map { "$\($0)" }
  }

  var disclaimer: String {
    localized(
      en: "AI-written from market data. Not financial advice.",
      pt: "Escrito por IA a partir de dados de mercado. Não constitui aconselhamento financeiro."
    )
  }

  /// The items quoted on the image and in Discord.
  var topItems: [MarketBriefItem] { Array(brief.items.prefix(Self.maxItems)) }

  // MARK: Links

  /// `https://www.norviq.org/brief/2026-10-15/morning`, plus `lang=pt-PT` for a
  /// Portuguese brief and the UTM pair when a channel is given.
  func permalink(for channel: MarketBriefShareChannel? = nil) -> URL {
    var components = URLComponents()
    components.scheme = baseURL.scheme
    components.host = baseURL.host()
    components.port = baseURL.port
    components.path = "/brief/\(tradingDate)/\(slot.rawValue)"
    var query: [URLQueryItem] = []
    if isPortuguese {
      query.append(URLQueryItem(name: "lang", value: languageCode))
    }
    if let channel {
      query.append(URLQueryItem(name: "utm_source", value: channel.rawValue))
      query.append(URLQueryItem(name: "utm_medium", value: "share"))
    }
    components.queryItems = query.isEmpty ? nil : query
    return components.url ?? baseURL
  }

  /// Sent with the link through the share sheet: title and first headline.
  var linkMessage: String {
    [title, headline].compactMap(\.self).joined(separator: "\n")
  }

  /// Sent with the image, so whoever sees it can find the page.
  var imageMessage: String {
    "\(title)\n\(permalink(for: .image).absoluteString)"
  }

  /// Title, headline, cashtags and permalink in at most 280 characters. The
  /// headline is shortened first, then the cashtags dropped.
  var xText: String {
    let link = permalink(for: .x).absoluteString
    let tags = cashtags.joined(separator: " ")

    func compose(headline: String?, tags: String) -> String {
      [title, headline, tags.isEmpty ? nil : tags, link]
        .compactMap(\.self)
        .joined(separator: "\n")
    }

    for tags in [tags, ""] {
      let withoutHeadline = compose(headline: nil, tags: tags)
      guard let headline else {
        if withoutHeadline.count <= Self.xCharacterLimit { return withoutHeadline }
        continue
      }
      let full = compose(headline: headline, tags: tags)
      if full.count <= Self.xCharacterLimit { return full }
      // Room for the headline: the limit, less everything else and its newline.
      let room = Self.xCharacterLimit - withoutHeadline.count - 1
      if room >= 20 {
        return compose(headline: Self.truncated(headline, to: room), tags: tags)
      }
    }
    return Self.truncated(compose(headline: nil, tags: ""), to: Self.xCharacterLimit)
  }

  /// Nil only if the text could not be encoded; the share sheet takes over then.
  var xIntentURL: URL? {
    URL(string: "https://x.com/intent/tweet?text=\(Self.queryEncoded(xText))")
  }

  var redditURL: URL? {
    let url = Self.queryEncoded(permalink(for: .reddit).absoluteString)
    return URL(string: "https://www.reddit.com/submit?url=\(url)&title=\(Self.queryEncoded(title))")
  }

  var whatsAppText: String {
    [title, headline, permalink(for: .whatsapp).absoluteString]
      .compactMap(\.self)
      .joined(separator: "\n")
  }

  var whatsAppURL: URL? {
    URL(string: "https://wa.me/?text=\(Self.queryEncoded(whatsAppText))")
  }

  /// Bold title, the index rows, the top items, the permalink and the disclaimer.
  var discordMarkdown: String {
    var lines = ["**\(title)**"]
    for group in brief.groups where !group.rows.isEmpty {
      lines.append("")
      lines.append("__\(group.title)__")
      for row in group.rows {
        lines.append("\(row.flag) \(row.name) \(row.level) \(Self.arrow(row.direction)) \(row.changePercent)")
      }
    }
    let items = topItems
    if !items.isEmpty {
      lines.append("")
      var storyNumber = 0
      for item in items {
        let marker: String
        switch item.kind {
        case .highlight: marker = "📌"
        case .earnings: marker = "📍"
        case .story:
          storyNumber += 1
          marker = "\(storyNumber)."
        }
        lines.append("\(marker) \(Self.singleLine(item.text))")
      }
    }
    lines.append("")
    lines.append(permalink(for: .discord).absoluteString)
    lines.append("_\(disclaimer)_")
    return lines.joined(separator: "\n")
  }

  // MARK: Helpers

  /// ▲ / ▼ / –; the formatted percentage is unsigned.
  static func arrow(_ direction: MarketBriefDirection) -> String {
    switch direction {
    case .up: "▲"
    case .down: "▼"
    case .flat: "–"
    }
  }

  /// RFC 3986 unreserved characters only, so `&`, `=`, `?` and `+` inside a
  /// value can never end it early.
  static func queryEncoded(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
  }

  private static let unreserved = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
  )

  private static func isCashtagSymbol(_ symbol: String) -> Bool {
    (1...6).contains(symbol.count) && symbol.allSatisfy { $0.isASCII && $0.isUppercase }
  }

  /// Collapses line breaks, so a line of the brief stays one line wherever it goes.
  static func singleLine(_ text: String) -> String {
    text.split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  /// At most `limit` characters, ending in "…" when cut.
  private static func truncated(_ text: String, to limit: Int) -> String {
    guard text.count > limit else { return text }
    guard limit > 1 else { return String(text.prefix(max(0, limit))) }
    return text.prefix(limit - 1).trimmingCharacters(in: .whitespaces) + "…"
  }

  private func localized(en: String, pt: String) -> String {
    isPortuguese ? pt : en
  }
}
