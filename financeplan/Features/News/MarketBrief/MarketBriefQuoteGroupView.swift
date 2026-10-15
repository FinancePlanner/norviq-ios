import StockPlanShared
import SwiftUI

/// A headed block of index rows, e.g. "Futuros americanos negativos". The
/// title takes the tone the server worked out from the rows.
struct MarketBriefQuoteGroupView: View {
  let group: MarketBriefQuoteGroup
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(verbatim: group.title)
        .typography(.nano, weight: .semibold)
        .foregroundStyle(group.tone.color(for: colorScheme))
        .accessibilityAddTraits(.isHeader)

      VStack(spacing: 4) {
        ForEach(group.rows, id: \.symbol) { row in
          MarketBriefQuoteRowView(row: row)
        }
      }
    }
  }
}

private struct MarketBriefQuoteRowView: View {
  let row: MarketBriefQuoteRow
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(verbatim: row.flag)
        .accessibilityHidden(true)
      Text(verbatim: row.name)
        .typography(.nano)
        .lineLimit(2)
      Spacer(minLength: 8)
      Text(verbatim: row.level)
        .typography(.numericSmall)
      HStack(spacing: 4) {
        Image(systemName: row.direction.systemImage)
          .imageScale(.small)
        Text(verbatim: row.changePercent)
          .typography(.numericSmall, weight: .semibold)
      }
      .foregroundStyle(row.direction.color(for: colorScheme))
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText)
  }

  private var accessibilityText: Text {
    switch row.direction {
    case .up: Text("\(row.name), \(row.level), up \(row.changePercent)")
    case .down: Text("\(row.name), \(row.level), down \(row.changePercent)")
    case .flat: Text("\(row.name), \(row.level), unchanged")
    }
  }
}
