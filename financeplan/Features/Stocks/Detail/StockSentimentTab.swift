import SwiftUI

struct StockSentimentTab: View {
    let symbol: String
    let response: TickerSentimentResponse?
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 20) {
            if isLoading, response == nil {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if let response, !response.posts.isEmpty {
                SentimentAggregateHeader(symbol: symbol, aggregate: response.aggregate)
                VStack(spacing: 12) {
                    ForEach(response.posts) { post in
                        SentimentPostCard(post: post)
                    }
                }
            } else {
                ResearchPlaceholderCard(
                    title: "No sentiment yet",
                    bodyText: "We don't have notable-account posts for \(symbol) yet. Popular holdings are refreshed regularly."
                )
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
