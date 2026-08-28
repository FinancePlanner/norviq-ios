import StockPlanShared
import SwiftUI

/// Label / value rows for the verified numbers on an AI card.
///
/// Moved out of `InsightCardView`, where it was private, so the per-view
/// summary sheet shows figures identically to the insight cards rather than
/// growing a second look for the same data. Body unchanged in the move.
///
/// Every value here is computed server-side; the model never supplies a number
/// that reaches this view.
struct AIHighlightRows: View {
    let highlights: [AIInsightHighlight]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(highlights) { highlight in
                HStack {
                    Text(highlight.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        if let symbol = trendSymbol(highlight.trend) {
                            Image(systemName: symbol)
                                .font(.caption2)
                        }
                        Text(highlight.value)
                            .font(.callout.weight(.semibold))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func trendSymbol(_ trend: String?) -> String? {
        switch trend?.lowercased() {
        case "up": "arrow.up.right"
        case "down": "arrow.down.right"
        case "flat": "arrow.right"
        default: nil
        }
    }
}
