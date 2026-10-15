import StockPlanShared
import SwiftUI

/// The 1080×1350 image shared from the brief card (Instagram, WhatsApp status,
/// anywhere an image travels further than a link). Written in the brief's
/// language and always drawn light, like `PortfolioShareCard`.
struct MarketBriefShareCard: View {
  static let size = CGSize(width: 1080, height: 1350)

  let payload: MarketBriefSharePayload

  var body: some View {
    VStack(alignment: .leading, spacing: 48) {
      header

      if !groups.isEmpty {
        VStack(alignment: .leading, spacing: 32) {
          ForEach(groups, id: \.id) { group in
            MarketBriefShareCardGroup(group: group)
          }
        }
      }

      if !payload.topItems.isEmpty {
        items
      }

      Spacer(minLength: 0)
      footer
    }
    .padding(72)
    .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    .background(Color(.systemBackground))
    // The shared image looks the same whatever mode the phone is in.
    .environment(\.colorScheme, .light)
  }

  private var groups: [MarketBriefQuoteGroup] {
    payload.brief.groups.filter { !$0.rows.isEmpty }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 20) {
        Image(systemName: payload.slot == .evening ? "moon.stars.fill" : "sunrise.fill")
          .foregroundStyle(AppTheme.Colors.tint)
        Text(verbatim: payload.slotTitle)
      }
      .font(.system(size: 64, weight: .bold))

      Text(verbatim: payload.dateLabel)
        .font(.system(size: 34))
        .foregroundStyle(.secondary)
    }
  }

  private var items: some View {
    // With every index row on the card, items get two lines each so the
    // footer never gets pushed off the image.
    let rowCount = groups.reduce(0) { $0 + $1.rows.count }
    let lineLimit = rowCount > 4 ? 2 : 3
    return VStack(alignment: .leading, spacing: 24) {
      ForEach(Array(numberedItems.enumerated()), id: \.offset) { _, entry in
        HStack(alignment: .firstTextBaseline, spacing: 16) {
          Text(verbatim: entry.marker)
            .foregroundStyle(.secondary)
            .frame(minWidth: 40, alignment: .leading)
          Text(verbatim: entry.text)
            .lineLimit(lineLimit)
        }
        .font(.system(size: 34))
      }
    }
  }

  private var numberedItems: [(marker: String, text: String)] {
    var storyNumber = 0
    return payload.topItems.map { item in
      switch item.kind {
      case .highlight: return ("📌", MarketBriefSharePayload.singleLine(item.text))
      case .earnings: return ("📍", MarketBriefSharePayload.singleLine(item.text))
      case .story:
        storyNumber += 1
        return ("\(storyNumber).", MarketBriefSharePayload.singleLine(item.text))
      }
    }
  }

  private var footer: some View {
    VStack(alignment: .leading, spacing: 24) {
      Divider()
      Text(verbatim: payload.disclaimer)
        .font(.system(size: 26))
        .foregroundStyle(.secondary)
      HStack(alignment: .center) {
        Image("NorviqFullLogo")
          .resizable()
          .scaledToFit()
          .frame(height: 56)
          .accessibilityLabel("Norviq")
        Spacer()
        Text(verbatim: "norviq.org")
          .font(.system(size: 34, weight: .semibold))
          .foregroundStyle(AppTheme.Colors.tint)
      }
    }
  }
}
