import StockPlanShared
import SwiftUI

/// One line of the brief: a morning 📌 highlight or 📍 earnings line, or a
/// numbered evening story. Tickers sit underneath as small capsules, and the
/// source is named as plain text, never linked.
struct MarketBriefItemRow: View {
  let item: MarketBriefItem
  /// 1-based position among the stories, for the evening numbering.
  let number: Int

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      marker
        .frame(minWidth: 20, alignment: .leading)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 6) {
        Text(verbatim: item.text)
          .typography(.small)
          .fixedSize(horizontal: false, vertical: true)

        if !item.tickers.isEmpty {
          tickers
        }

        if let host = MarketBriefFormat.sourceHost(item.sourceUrl) {
          Text("Source: \(host)")
            .typography(.footnote)
            .foregroundStyle(.tertiary)
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }

  @ViewBuilder private var marker: some View {
    switch item.kind {
    case .highlight:
      Text(verbatim: "📌")
    case .earnings:
      Text(verbatim: "📍")
    case .story:
      Text(verbatim: "\(number).")
        .typography(.small, weight: .semibold)
        .foregroundStyle(.secondary)
    }
  }

  private var tickers: some View {
    // A wrapped column when the row would not fit, e.g. at the largest text sizes.
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 4) { tickerCapsules }
      VStack(alignment: .leading, spacing: 4) { tickerCapsules }
    }
  }

  private var tickerCapsules: some View {
    ForEach(item.tickers, id: \.self) { ticker in
      Text(verbatim: ticker)
        .typography(.footnote, weight: .semibold)
        .monospaced()
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(AppTheme.Colors.elevatedCardBackground, in: .capsule)
        .overlay {
          Capsule().stroke(AppTheme.Colors.separator, lineWidth: 1)
        }
    }
  }

  /// Leads with what the emoji says, so VoiceOver does not read "pushpin".
  private var accessibilityLabel: Text {
    let tickers = item.tickers.joined(separator: ", ")
    let source = MarketBriefFormat.sourceHost(item.sourceUrl)
    var label: Text = switch item.kind {
    case .highlight: Text("Highlight: \(item.text)")
    case .earnings: Text("Earnings: \(item.text)")
    case .story: Text("Story \(number): \(item.text)")
    }
    if !tickers.isEmpty {
      label = label + Text(verbatim: ". ") + Text("Tickers: \(tickers)")
    }
    if let source {
      label = label + Text(verbatim: ". ") + Text("Source: \(source)")
    }
    return label
  }
}
