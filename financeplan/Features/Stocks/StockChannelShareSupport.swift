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
  case discord
}

enum StockShareDestination: String, CaseIterable, Identifiable {
  case x
  case discord

  var id: String { rawValue }

  var title: String {
    switch self {
    case .x:
      return "X"
    case .discord:
      return "Discord"
    }
  }

  var icon: String {
    switch self {
    case .x:
      return "bubble.left.and.bubble.right"
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
    lines.append(headline(localized(language, en: "Thesis update for $\(symbolUppercased)", pt: "Tese de investimento para $\(symbolUppercased)"), style: style))
    if let details {
      let costBasis = (details.shares * details.buyPrice).currency
      lines.append(
        listLine(
          localized(
          language,
          en: "Position: \(details.shares.formatted(.number.precision(.fractionLength(0...2)))) shares @ \(details.buyPrice.currency) (Cost basis \(costBasis))",
          pt: "Posição: \(details.shares.formatted(.number.precision(.fractionLength(0...2)))) ações @ \(details.buyPrice.currency) (Base de custo \(costBasis))"
          ),
          style: style
        )
      )
    }
    lines.append(listLine(localized(language, en: "Thesis: \(normalizeText(thesis))", pt: "Tese: \(normalizeText(thesis))"), style: style))
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
        headline("Fundamentals snapshot for $\(symbol)", style: style),
        listLine("Price: \(profile.currentPrice.currency)", style: style),
        listLine("Market cap: \(formatCompactCurrency(profile.marketCap))", style: style),
        listLine("TTM PE: \(ttmPE)", style: style),
        listLine("Gross margin: \(grossMargin)", style: style),
        listLine("Net margin: \(netMargin)", style: style),
        listLine("TTM revenue growth: \(ttmRevenueGrowth)", style: style),
        listLine("Next-year revenue growth: \(nextYearRevenueGrowth)", style: style),
        disclaimer(language)
      ]
    case .portuguesePortugal:
      lines = [
        headline("Fundamentais de $\(symbol)", style: style),
        listLine("Preço: \(profile.currentPrice.currency)", style: style),
        listLine("Market cap: \(formatCompactCurrency(profile.marketCap))", style: style),
        listLine("TTM PE: \(ttmPE)", style: style),
        listLine("Margem bruta: \(grossMargin)", style: style),
        listLine("Margem líquida: \(netMargin)", style: style),
        listLine("Crescimento receita TTM: \(ttmRevenueGrowth)", style: style),
        listLine("Crescimento receita próximo ano: \(nextYearRevenueGrowth)", style: style),
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
        headline("Price targets for $\(symbolUppercased)", style: style),
        listLine("Current price: \(current > 0 ? current.currency : "n/a")", style: style),
        listLine("Bear: \(valuation.bearCase.low.currency) - \(valuation.bearCase.high.currency)", style: style),
        listLine("Base: \(valuation.baseCase.low.currency) - \(valuation.baseCase.high.currency)", style: style),
        listLine("Bull: \(valuation.bullCase.low.currency) - \(valuation.bullCase.high.currency)", style: style),
        listLine("Base midpoint implied return: \(impliedUpside)", style: style),
        disclaimer(language)
      ]
    case .portuguesePortugal:
      lines = [
        headline("Preços-alvo para $\(symbolUppercased)", style: style),
        listLine("Preço atual: \(current > 0 ? current.currency : "n/a")", style: style),
        listLine("Bear: \(valuation.bearCase.low.currency) - \(valuation.bearCase.high.currency)", style: style),
        listLine("Base: \(valuation.baseCase.low.currency) - \(valuation.baseCase.high.currency)", style: style),
        listLine("Bull: \(valuation.bullCase.low.currency) - \(valuation.bullCase.high.currency)", style: style),
        listLine("Retorno implícito no ponto médio base: \(impliedUpside)", style: style),
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
    let reserve = "...\nNot investment advice."
    let limit = max(0, 280 - reserve.count)
    return String(body.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + reserve
  }

  private static func headline(_ text: String, style: StockShareTextStyle) -> String {
    style == .discord ? "**\(text)**" : text
  }

  private static func listLine(_ text: String, style: StockShareTextStyle) -> String {
    style == .discord ? "• \(text)" : text
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
      ShareSheet(items: shareSheetItems)
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
    case .discord:
      copyForDiscordAndOpen(payload.body)
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

  private func copyForDiscordAndOpen(_ body: String) {
#if canImport(UIKit)
    UIPasteboard.general.string = body
#endif
    showBanner("Opening Discord. Please paste your text there.", style: .success)

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
