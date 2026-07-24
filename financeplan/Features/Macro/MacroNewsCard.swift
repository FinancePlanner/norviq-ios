import StockPlanShared
import SwiftUI

/// Market/economy headlines card for the Macro screen. Rows open the article
/// in the browser; layout matches the sibling Macro*Card chrome.
struct MacroNewsCard: View {
  let news: [StockNews]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Market news")
        .font(.headline)

      ForEach(news.prefix(6)) { item in
        if let url = URL(string: item.url) {
          Link(destination: url) {
            MacroNewsRow(item: item)
          }
          .buttonStyle(.plain)
        } else {
          MacroNewsRow(item: item)
        }
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
}

private struct MacroNewsRow: View {
  let item: StockNews

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 5) {
        if let source = item.source, !source.isEmpty {
          Text(source)
        }
        if item.source?.isEmpty == false, MacroNewsDateFormatting.relative(from: item.date) != nil {
          Text("·")
        }
        if let relative = MacroNewsDateFormatting.relative(from: item.date) {
          Text(relative)
        }
      }
      .font(.caption2.weight(.semibold))
      .foregroundStyle(.secondary)

      Text(item.title)
        .font(.callout)
        .foregroundStyle(.primary)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 4)
    .contentShape(.rect)
  }
}

/// Defensive ISO/date-string parsing: an unparseable date hides the
/// timestamp, never the row.
enum MacroNewsDateFormatting {
  nonisolated static func relative(from raw: String) -> String? {
    guard let date = parse(raw) else { return nil }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
  }

  nonisolated static func parse(_ raw: String) -> Date? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let isoWithFraction = ISO8601DateFormatter()
    isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = isoWithFraction.date(from: trimmed) { return date }

    let iso = ISO8601DateFormatter()
    if let date = iso.date(from: trimmed) { return date }

    let fallback = DateFormatter()
    fallback.locale = Locale(identifier: "en_US_POSIX")
    fallback.timeZone = TimeZone(identifier: "UTC")
    for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
      fallback.dateFormat = format
      if let date = fallback.date(from: trimmed) { return date }
    }
    return nil
  }
}
