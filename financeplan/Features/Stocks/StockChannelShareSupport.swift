import Foundation
import SwiftUI
import StockPlanShared

#if canImport(UIKit)
import UIKit
#endif

struct StockSharePayload: Equatable {
  let title: String
  let body: String
}

enum StockShareTextStyle {
  case native
  case x
  case stockTwits
  case discord
}

enum StockShareDestination: String, CaseIterable, Identifiable {
  case x
  case stockTwits
  case discord

  var id: String { rawValue }

  var title: String {
    switch self {
    case .x:
      return "X"
    case .stockTwits:
      return "StockTwits"
    case .discord:
      return "Discord"
    }
  }

  var icon: String {
    switch self {
    case .x:
      return "bubble.left.and.bubble.right"
    case .stockTwits:
      return "chart.line.uptrend.xyaxis"
    case .discord:
      return "message"
    }
  }
}

enum StockSharePayloadFormatter {
  static func thesis(
    symbol: String,
    thesis: String,
    details: StockPlanShared.StockResponse?,
    language: AppLanguage = .stored,
    style: StockShareTextStyle = .native
  ) -> StockSharePayload {
    var lines: [String] = []
    let symbolUppercased = symbol.uppercased()
    lines.append(localized(language, en: "Thesis update for $\(symbolUppercased)", pt: "Tese de investimento para $\(symbolUppercased)"))
    if let details {
      let costBasis = (details.shares * details.buyPrice).currency
      lines.append(
        localized(
          language,
          en: "Position: \(details.shares.formatted(.number.precision(.fractionLength(0...2)))) shares @ \(details.buyPrice.currency) (Cost basis \(costBasis))",
          pt: "Posição: \(details.shares.formatted(.number.precision(.fractionLength(0...2)))) ações @ \(details.buyPrice.currency) (Base de custo \(costBasis))"
        )
      )
    }
    lines.append(localized(language, en: "Thesis: \(normalizeText(thesis))", pt: "Tese: \(normalizeText(thesis))"))
    lines.append(disclaimer(language))

    return StockSharePayload(
      title: localized(language, en: "\(symbolUppercased) thesis", pt: "Tese \(symbolUppercased)"),
      body: constrained(lines.joined(separator: "\n"), style: style)
    )
  }

  static func fundamentals(
    profile: StockComparisonProfile,
    language: AppLanguage = .stored,
    style: StockShareTextStyle = .native
  ) -> StockSharePayload {
    let symbol = profile.symbol.uppercased()
    let ttmPE = formatMultiple(profile.metrics[.ttmPE])
    let grossMargin = formatPercent(profile.metrics[.grossMargin])
    let netMargin = formatPercent(profile.metrics[.netMargin])
    let ttmRevenueGrowth = formatPercent(profile.metrics[.ttmRevenueGrowth])
    let nextYearRevenueGrowth = formatPercent(profile.metrics[.nextYearRevenueGrowth])

    let lines: [String]
    switch language {
    case .english:
      lines = [
        "Fundamentals snapshot for $\(symbol)",
        "Price: \(profile.currentPrice.currency)",
        "Market cap: \(formatCompactCurrency(profile.marketCap))",
        "TTM PE: \(ttmPE)",
        "Gross margin: \(grossMargin)",
        "Net margin: \(netMargin)",
        "TTM revenue growth: \(ttmRevenueGrowth)",
        "Next-year revenue growth: \(nextYearRevenueGrowth)",
        disclaimer(language)
      ]
    case .portuguesePortugal:
      lines = [
        "Fundamentais de $\(symbol)",
        "Preço: \(profile.currentPrice.currency)",
        "Market cap: \(formatCompactCurrency(profile.marketCap))",
        "TTM PE: \(ttmPE)",
        "Margem bruta: \(grossMargin)",
        "Margem líquida: \(netMargin)",
        "Crescimento receita TTM: \(ttmRevenueGrowth)",
        "Crescimento receita próximo ano: \(nextYearRevenueGrowth)",
        disclaimer(language)
      ]
    }

    return StockSharePayload(
      title: localized(language, en: "\(symbol) fundamentals", pt: "Fundamentais \(symbol)"),
      body: constrained(lines.joined(separator: "\n"), style: style)
    )
  }

  static func priceTargets(
    symbol: String,
    valuation: StockPlanShared.StockValuationRequest,
    currentPrice: Double?,
    language: AppLanguage = .stored,
    style: StockShareTextStyle = .native
  ) -> StockSharePayload {
    let symbolUppercased = symbol.uppercased()
    let baseMid = (valuation.baseCase.low + valuation.baseCase.high) / 2
    let current = currentPrice ?? 0

    let impliedUpside: String = {
      guard current > 0 else { return "n/a" }
      let value = ((baseMid - current) / current)
      return formatSignedPercent(value)
    }()

    let lines: [String]
    switch language {
    case .english:
      lines = [
        "Price targets for $\(symbolUppercased)",
        "Current price: \(current > 0 ? current.currency : "n/a")",
        "Bear: \(valuation.bearCase.low.currency) - \(valuation.bearCase.high.currency)",
        "Base: \(valuation.baseCase.low.currency) - \(valuation.baseCase.high.currency)",
        "Bull: \(valuation.bullCase.low.currency) - \(valuation.bullCase.high.currency)",
        "Base midpoint implied return: \(impliedUpside)",
        disclaimer(language)
      ]
    case .portuguesePortugal:
      lines = [
        "Preços-alvo para $\(symbolUppercased)",
        "Preço atual: \(current > 0 ? current.currency : "n/a")",
        "Bear: \(valuation.bearCase.low.currency) - \(valuation.bearCase.high.currency)",
        "Base: \(valuation.baseCase.low.currency) - \(valuation.baseCase.high.currency)",
        "Bull: \(valuation.bullCase.low.currency) - \(valuation.bullCase.high.currency)",
        "Retorno implícito no ponto médio base: \(impliedUpside)",
        disclaimer(language)
      ]
    }

    return StockSharePayload(
      title: localized(language, en: "\(symbolUppercased) price targets", pt: "Preços-alvo \(symbolUppercased)"),
      body: constrained(lines.joined(separator: "\n"), style: style)
    )
  }

  static func basePrice(
    symbol: String,
    valuation: StockPlanShared.StockValuationRequest,
    currentPrice: Double?
  ) -> StockSharePayload {
    priceTargets(symbol: symbol, valuation: valuation, currentPrice: currentPrice)
  }

  private static func normalizeText(_ text: String) -> String {
    text
      .split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  private static func localized(_ language: AppLanguage, en: String, pt: String) -> String {
    switch language {
    case .english: en
    case .portuguesePortugal: pt
    }
  }

  private static func disclaimer(_ language: AppLanguage) -> String {
    localized(language, en: "Not investment advice.", pt: "Não é aconselhamento financeiro.")
  }

  private static func constrained(_ body: String, style: StockShareTextStyle) -> String {
    guard style == .x, body.count > 280 else { return body }
    let reserve = "…\nNot investment advice."
    let limit = max(0, 280 - reserve.count)
    return String(body.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + reserve
  }

  private static func formatPercent(_ value: Double?) -> String {
    guard let value else { return "n/a" }
    return value.formatted(.percent.precision(.fractionLength(1)))
  }

  private static func formatMultiple(_ value: Double?) -> String {
    guard let value else { return "n/a" }
    return value.formatted(.number.precision(.fractionLength(1))) + "x"
  }

  private static func formatSignedPercent(_ value: Double) -> String {
    let absolute = abs(value).formatted(.percent.precision(.fractionLength(1)))
    if value > 0 { return "+\(absolute)" }
    if value < 0 { return "-\(absolute)" }
    return absolute
  }

  private static func formatCompactCurrency(_ value: Double) -> String {
    let number = NSNumber(value: value)
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.maximumFractionDigits = 1
    formatter.minimumFractionDigits = 0

    if abs(value) >= 1_000_000_000 {
      return "\(formatter.string(from: NSNumber(value: value / 1_000_000_000)) ?? "$0")B"
    }
    if abs(value) >= 1_000_000 {
      return "\(formatter.string(from: NSNumber(value: value / 1_000_000)) ?? "$0")M"
    }
    if abs(value) >= 1_000 {
      return "\(formatter.string(from: NSNumber(value: value / 1_000)) ?? "$0")K"
    }
    return formatter.string(from: number) ?? "$0"
  }
}

struct StockChannelShareActions: View {
  let payload: StockSharePayload
  let destinationPayload: ((StockShareDestination) -> StockSharePayload)?

  @Environment(\.openURL) private var openURL
  @State private var shareSheetItems: [Any] = []
  @State private var isShareSheetPresented = false
  @State private var bannerMessage: String?
  @State private var bannerStyle: ToastBanner.Style = .info
  @State private var hideBannerTask: Task<Void, Never>?

  init(
    payload: StockSharePayload,
    destinationPayload: ((StockShareDestination) -> StockSharePayload)? = nil
  ) {
    self.payload = payload
    self.destinationPayload = destinationPayload
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: "square.and.arrow.up")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text("Share")
          .typography(.caption, weight: .semibold)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 8) {
        ForEach(StockShareDestination.allCases) { destination in
          Button {
            share(to: destination)
          } label: {
            Label(destination.title, systemImage: destination.icon)
              .font(.caption.weight(.semibold))
              .lineLimit(1)
              .padding(.horizontal, 10)
              .padding(.vertical, 8)
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        }
      }

      if let bannerMessage {
        ToastBanner(message: bannerMessage, style: bannerStyle)
      }
    }
    .sheet(isPresented: $isShareSheetPresented) {
      StockTextShareSheet(items: shareSheetItems)
    }
    .onDisappear {
      hideBannerTask?.cancel()
    }
  }

  private func share(to destination: StockShareDestination) {
    let payload = payload(for: destination)
    switch destination {
    case .x:
      openPrefilledURL(
        "https://x.com/intent/tweet?text=\(percentEncoded(payload.body))",
        fallbackItems: [payload.body]
      )
    case .stockTwits:
      openPrefilledURL(
        "https://stocktwits.com/message/new?body=\(percentEncoded(payload.body))",
        fallbackItems: [payload.body]
      )
    case .discord:
      copyForDiscordAndOpen()
    }
  }

  private func payload(for destination: StockShareDestination) -> StockSharePayload {
    destinationPayload?(destination) ?? payload
  }

  private func openPrefilledURL(_ rawURL: String, fallbackItems: [Any]) {
    guard let url = URL(string: rawURL) else {
      showBanner("Could not build share link. Opened iOS share sheet instead.", style: .error)
      openShareSheet(items: fallbackItems)
      return
    }

    openURL(url) { accepted in
      if !accepted {
        showBanner("Share target unavailable. Opened iOS share sheet.", style: .info)
        openShareSheet(items: fallbackItems)
      }
    }
  }

  private func copyForDiscordAndOpen() {
    #if canImport(UIKit)
    UIPasteboard.general.string = payload.body
    #endif
    showBanner("Copied text for Discord. Paste it in your channel.", style: .success)

    guard let discordAppURL = URL(string: "discord://") else { return }
    openURL(discordAppURL) { accepted in
      guard !accepted else { return }
      if let webURL = URL(string: "https://discord.com/channels/@me") {
        openURL(webURL)
      }
    }
  }

  private func openShareSheet(items: [Any]) {
    shareSheetItems = items
    isShareSheetPresented = true
  }

  private func percentEncoded(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
  }

  private func showBanner(_ message: String, style: ToastBanner.Style) {
    bannerStyle = style
    bannerMessage = message

    hideBannerTask?.cancel()
    hideBannerTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled else { return }
      bannerMessage = nil
    }
  }
}

#if canImport(UIKit)
private struct StockTextShareSheet: UIViewControllerRepresentable {
  let items: [Any]

  func makeUIViewController(context _: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
#else
private struct StockTextShareSheet: View {
  let items: [Any]

  var body: some View {
    Text(items.compactMap { $0 as? String }.joined(separator: "\n\n"))
      .padding()
  }
}
#endif
