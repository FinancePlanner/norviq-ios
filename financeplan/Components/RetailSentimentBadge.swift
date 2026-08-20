import SwiftUI

/// Presentation model for one symbol's retail-sentiment reading.
///
/// `hasReading` is load-bearing. A symbol nobody is posting about carries no
/// score, which is not the same as a balanced one — rendering absence as
/// "Neutral 0" would assert a consensus that was never observed.
struct RetailSentimentDisplay: Equatable {
    let hasReading: Bool
    let label: String
    let scoreText: String
    let deltaText: String?
    let deltaUp: Bool
    let postText: String

    static let none = RetailSentimentDisplay(
        hasReading: false,
        label: "No chatter",
        scoreText: "",
        deltaText: nil,
        deltaUp: false,
        postText: ""
    )

    init(
        hasReading: Bool,
        label: String,
        scoreText: String,
        deltaText: String?,
        deltaUp: Bool,
        postText: String
    ) {
        self.hasReading = hasReading
        self.label = label
        self.scoreText = scoreText
        self.deltaText = deltaText
        self.deltaUp = deltaUp
        self.postText = postText
    }

    init(_ sentiment: SymbolSentiment?) {
        guard let sentiment, let score = sentiment.score else {
            self = .none
            return
        }

        var delta: String?
        var up = false
        if let raw = sentiment.delta1d, abs(raw) >= 0.01 {
            delta = String(format: "%+.2f", raw)
            up = raw > 0
        }

        self.init(
            hasReading: true,
            label: sentiment.label.capitalized,
            // Rendered on a -100…100 scale: two decimals on a crowd-derived
            // number reads as precision that is not there.
            scoreText: String(format: "%+.0f", score * 100),
            deltaText: delta,
            deltaUp: up,
            postText: Self.postLabel(sentiment.postCount)
        )
    }

    static func postLabel(_ count: Int) -> String {
        count == 1 ? "1 post" : "\(count) posts"
    }

    static func color(for label: String) -> Color {
        switch label.lowercased() {
        case "bullish", "positive": return .green
        case "bearish", "negative": return .red
        default: return .secondary
        }
    }
}

/// Compact sentiment pill for list rows and headers.
///
/// The no-reading case gets a distinct, dimmer treatment rather than a neutral
/// pill, so "we measured nothing" never looks like "the crowd is split".
struct RetailSentimentBadge: View {
    let display: RetailSentimentDisplay
    var showsScore: Bool = true

    private var color: Color {
        RetailSentimentDisplay.color(for: display.label)
    }

    var body: some View {
        if display.hasReading {
            HStack(spacing: 4) {
                Text(display.label)
                    .font(.caption2.weight(.semibold))
                if showsScore {
                    Text(display.scoreText)
                        .font(.caption2.monospacedDigit())
                        .opacity(0.7)
                }
                if let deltaText = display.deltaText {
                    Text(deltaText)
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(display.deltaUp ? Color.green : Color.red)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Retail sentiment \(display.label), \(display.postText)")
        } else {
            Text(display.label)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .overlay(
                    Capsule().strokeBorder(
                        Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 2])
                    )
                )
                .foregroundStyle(.secondary.opacity(0.7))
                .accessibilityLabel("No retail chatter measured")
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        RetailSentimentBadge(display: RetailSentimentDisplay(
            hasReading: true,
            label: "Bullish",
            scoreText: "+42",
            deltaText: "+0.12",
            deltaUp: true,
            postText: "31 posts"
        ))
        RetailSentimentBadge(display: RetailSentimentDisplay(
            hasReading: true,
            label: "Bearish",
            scoreText: "-28",
            deltaText: "-0.20",
            deltaUp: false,
            postText: "9 posts"
        ))
        RetailSentimentBadge(display: .none)
    }
    .padding()
}
