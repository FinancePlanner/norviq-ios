import SwiftUI

struct CSVImportFormatHint: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("CSV format")
        .typography(.small, weight: .semibold)

      Text(
        "Include a header row. Required: symbol, shares, buy_price, buy_date. Notes is optional."
      )
      .typography(.caption)
      .foregroundStyle(.secondary)

      Text("symbol,shares,buy_price,buy_date,notes")
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "CSV format. Header row required with columns symbol, shares, buy price, buy date, and optional notes."
    )
  }
}

struct WatchlistCSVImportFormatHint: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Watchlist CSV format")
        .typography(.small, weight: .semibold)

      Text("Include a header row. Required: symbol or ticker. note, notes, memo, or comment is optional.")
        .typography(.caption)
        .foregroundStyle(.secondary)

      Text("symbol,notes")
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Watchlist CSV format. Header row required with symbol or ticker. note, notes, memo, or comment are optional.")
  }
}

#if DEBUG
#Preview {
  CSVImportFormatHint()
    .padding()
}
#endif
