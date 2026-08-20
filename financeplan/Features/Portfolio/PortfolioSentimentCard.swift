import SwiftUI

/// Portfolio-wide retail sentiment.
///
/// Coverage is rendered next to the score at all times, and called out when it
/// is thin. The backend computes the weighted score over only the positions
/// that carry a reading, so presenting the number alone would let a reading
/// drawn from two holdings look like it speaks for the whole portfolio.
struct PortfolioSentimentCard: View {
    let response: PortfolioSentimentResponse
    var onSeeTrending: (() -> Void)?

    /// Below this, the roll-up is presented as indicative rather than
    /// representative.
    static let thinCoverageThreshold = 0.5

    private var display: RetailSentimentDisplay {
        guard let score = response.score else { return .none }
        return RetailSentimentDisplay(
            hasReading: true,
            label: response.label.capitalized,
            scoreText: String(format: "%+.0f", score * 100),
            deltaText: nil,
            deltaUp: false,
            postText: RetailSentimentDisplay.postLabel(response.postCount)
        )
    }

    private var isThin: Bool {
        response.coverage < Self.thinCoverageThreshold
    }

    private var coverageText: String {
        guard response.symbolsTotal > 0 else { return "No positions" }
        let percent = Int((response.coverage * 100).rounded())
        return "\(response.symbolsCovered) of \(response.symbolsTotal) positions (\(percent)%)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Retail sentiment")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let onSeeTrending {
                    Button("Trending", action: onSeeTrending)
                        .font(.caption)
                }
            }

            HStack(spacing: 10) {
                RetailSentimentBadge(display: display)
                if let asOf = response.asOfDate {
                    Text("Measured \(asOf)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(isThin
                ? "Based on \(coverageText) — too thin to speak for the whole portfolio."
                : "Based on \(coverageText).")
                .font(.caption2)
                .foregroundStyle(isThin ? Color.orange : Color.secondary)

            if response.mostBullish != nil || response.mostBearish != nil {
                HStack(spacing: 12) {
                    if let bullish = response.mostBullish {
                        Label("Most bullish: \(bullish.symbol)", systemImage: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    if let bearish = response.mostBearish {
                        Label("Most bearish: \(bearish.symbol)", systemImage: "arrow.down.right")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
