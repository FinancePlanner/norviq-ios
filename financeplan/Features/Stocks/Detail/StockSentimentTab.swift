import SwiftUI

struct StockSentimentTab: View {
    let symbol: String
    let response: TickerSentimentResponse?
    var daily: SymbolSentiment?
    var history: [SymbolSentiment] = []
    let isLoading: Bool

    private var hasNotablePosts: Bool {
        !(response?.posts.isEmpty ?? true)
    }

    private var hasAnything: Bool {
        daily != nil || hasNotablePosts
    }

    var body: some View {
        VStack(spacing: 20) {
            if isLoading, !hasAnything {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if hasAnything {
                if let daily {
                    DailySentimentCard(sentiment: daily, history: history)
                }
                if let response, hasNotablePosts {
                    SentimentAggregateHeader(symbol: symbol, aggregate: response.aggregate)
                    VStack(spacing: 12) {
                        ForEach(response.posts) { post in
                            SentimentPostCard(post: post)
                        }
                    }
                }
                Text("Sentiment describes what retail investors are posting, not whether they are right. Not investment advice.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ResearchPlaceholderCard(
                    title: "No sentiment yet",
                    bodyText: "We don't have retail posts for \(symbol) yet. Coverage grows as more people hold or watch it."
                )
            }
        }
    }
}

/// The broad daily reading, shown above the notable-post sample.
///
/// Both are labelled because they measure different populations over different
/// windows — unlabelled, two different numbers for the same symbol read as the
/// app contradicting itself.
private struct DailySentimentCard: View {
    let sentiment: SymbolSentiment
    let history: [SymbolSentiment]

    private var sourceText: String? {
        let counts = sentiment.sourceCounts
        let parts = [
            (counts.x, "X"),
            (counts.reddit, "Reddit"),
            (counts.stocktwits, "StockTwits"),
            (counts.news, "news"),
            (counts.investing, "Investing.com"),
            (counts.seekingAlpha, "Seeking Alpha"),
        ]
        .filter { $0.0 > 0 }
        .sorted { $0.0 > $1.0 }
        .map { "\($0.0) from \($0.1)" }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Retail chatter")
                        .font(.subheadline.weight(.semibold))
                    if let sourceText {
                        Text(sourceText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                RetailSentimentBadge(display: RetailSentimentDisplay(sentiment))
            }

            if let summary = sentiment.themes?.summary, !summary.isEmpty {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let themes = sentiment.themes?.themes, !themes.isEmpty {
                SentimentThemeFlow(themes: themes)
            }

            if history.count >= 2 {
                SentimentHistoryChart(history: history)
                    .frame(height: 120)
            }

            Text("Measured \(sentiment.asOfDate)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct SentimentThemeFlow: View {
    let themes: [SentimentTheme]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(themes) { theme in
                HStack(spacing: 6) {
                    Circle()
                        .fill(RetailSentimentDisplay.color(for: theme.stance))
                        .frame(width: 6, height: 6)
                    Text(theme.label)
                        .font(.caption)
                    Spacer()
                    Text(RetailSentimentDisplay.postLabel(theme.evidenceCount))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

private struct SentimentAggregateHeader: View {
    let symbol: String
    let aggregate: TickerSentimentAggregate

    var body: some View {
        HStack(spacing: 12) {
            SentimentBadge(label: aggregate.label)
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol)
                    .font(.headline)
                Text("\(aggregate.postCount) notable posts")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct SentimentPostCard: View {
    let post: TickerSentimentPost
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    if let author = post.author {
                        Text(author).font(.subheadline.weight(.semibold))
                    }
                    if let handle = post.authorHandle {
                        Text("@\(handle)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                SentimentBadge(label: post.sentimentLabel)
            }
            Text(post.text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
        .onTapGesture {
            if let urlString = post.url, let url = URL(string: urlString) {
                openURL(url)
            }
        }
    }
}

private struct SentimentBadge: View {
    let label: String

    private var color: Color {
        switch label.lowercased() {
        case "bullish", "positive": return .green
        case "bearish", "negative": return .red
        default: return .secondary
        }
    }

    var body: some View {
        Text(label.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
