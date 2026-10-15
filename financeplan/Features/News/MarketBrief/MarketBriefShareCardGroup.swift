import StockPlanShared
import SwiftUI

/// One headed block of index rows on the share image: flag, name, level and a
/// coloured ▲ / ▼ change. Sized for a 1080-point-wide canvas.
struct MarketBriefShareCardGroup: View {
  let group: MarketBriefQuoteGroup
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(verbatim: group.title.uppercased())
        .font(.system(size: 26, weight: .semibold))
        .tracking(1.5)
        .foregroundStyle(group.tone.color(for: colorScheme))

      VStack(spacing: 12) {
        ForEach(group.rows, id: \.symbol) { row in
          HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(verbatim: row.flag)
            Text(verbatim: row.name)
              .lineLimit(1)
            Spacer(minLength: 16)
            Text(verbatim: row.level)
              .monospacedDigit()
            Text(verbatim: "\(MarketBriefSharePayload.arrow(row.direction)) \(row.changePercent)")
              .fontWeight(.semibold)
              .monospacedDigit()
              .foregroundStyle(row.direction.color(for: colorScheme))
              .frame(width: 200, alignment: .trailing)
          }
          .font(.system(size: 34))
        }
      }
    }
  }
}
