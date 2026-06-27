import Factory
import StockPlanShared
import SwiftUI

struct StockNewsTab: View {
    let news: [StockNews]
    let defaultSymbol: String?
    let trackingMetadataByURL: [String: NewsArticleTrackingMetadata]
    @Environment(\.colorScheme) private var colorScheme

    init(
        news: [StockNews],
        defaultSymbol: String? = nil,
        trackingMetadataByURL: [String: NewsArticleTrackingMetadata] = [:]
    ) {
        self.news = news
        self.defaultSymbol = defaultSymbol
        self.trackingMetadataByURL = trackingMetadataByURL
    }

    var body: some View {
        VStack(spacing: 24) {
            if news.isEmpty {
                ResearchPlaceholderCard(
                    title: "No recent news",
                    bodyText: "Stay tuned for updates and market shifts."
                )
            } else {
                // 1. Featured Story (Text-only prominent card)
                if let first = news.first {
                    FeaturedNewsHero(news: first, metadata: metadata(for: first))
                }

                // 2. The Feed
                VStack(spacing: 16) {
                    ForEach(news.dropFirst(), id: \.url) { item in
                        NewsFeedRow(news: item, metadata: metadata(for: item))
                    }
                }
            }
        }
    }

    private func metadata(for news: StockNews) -> NewsArticleTrackingMetadata {
        trackingMetadataByURL[news.url] ?? NewsArticleTrackingMetadata(newsId: nil, symbol: defaultSymbol)
    }
}

struct NewsArticleTrackingMetadata: Equatable {
    let newsId: String?
    let symbol: String?
}

private struct FeaturedNewsHero: View {
    let news: StockNews
    let metadata: NewsArticleTrackingMetadata
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openTrackedNews(news, metadata: metadata, openURL: openURL)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(news.source?.uppercased() ?? "LATEST NEWS")
                        .typography(.nano, weight: .bold)
                        .foregroundStyle(AppTheme.Colors.secondaryTint(for: colorScheme))

                    Spacer()

                    Image(systemName: "newspaper.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.5))
                        .accessibilityLabel("News icon")
                }

                Text(news.title)
                    .typography(.label, weight: .bold)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                if let summary = news.summary, !summary.isEmpty {
                    Text(summary)
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }

                HStack {
                    Text(formatRelativeDate(news.date))
                        .typography(.nano)
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("Read full article")
                            .typography(.nano, weight: .semibold)
                        Image(systemName: "arrow.up.right")
                            .typography(.nano, weight: .bold)
                            .accessibilityLabel("Open external link")
                    }
                    .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                }
                .padding(.top, 4)
            }
            .padding(20)
            .appGlassEffect(.rect(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    private func formatRelativeDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else { return dateString }

        let now = Date()
        let diff = now.timeIntervalSince(date)

        if diff < 60 {
            return "Just now"
        } else if diff < 3600 {
            return "\(Int(diff / 60))m ago"
        } else if diff < 86400 {
            return "\(Int(diff / 3600))h ago"
        } else {
            let days = Int(diff / 86400)
            return "\(days)d ago"
        }
    }
}

private struct NewsFeedRow: View {
    let news: StockNews
    let metadata: NewsArticleTrackingMetadata
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openTrackedNews(news, metadata: metadata, openURL: openURL)
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(news.source ?? "Source")
                            .typography(.nano, weight: .bold)
                            .foregroundStyle(.secondary)

                        Circle()
                            .fill(.secondary.opacity(0.5))
                            .frame(width: 3, height: 3)

                        Text(formatRelativeDate(news.date))
                            .typography(.nano)
                            .foregroundStyle(.secondary)
                    }

                    Text(news.title)
                        .typography(.small, weight: .semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let summary = news.summary, !summary.isEmpty {
                        Text(summary)
                            .typography(.nano)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()

                // Thumbnail
                AsyncImage(url: URL(string: news.imageURL ?? "")) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.Colors.tertiaryFill(for: colorScheme))
                        .overlay(Image(systemName: "photo").font(.caption).foregroundStyle(.secondary))
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(12)
            .appGlassEffect(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private func formatRelativeDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else { return dateString }

        let now = Date()
        let diff = now.timeIntervalSince(date)

        if diff < 60 {
            return "Just now"
        } else if diff < 3600 {
            return "\(Int(diff / 60))m ago"
        } else if diff < 86400 {
            return "\(Int(diff / 3600))h ago"
        } else {
            let days = Int(diff / 86400)
            return "\(days)d ago"
        }
    }
}

@MainActor
private func openTrackedNews(_ news: StockNews, metadata: NewsArticleTrackingMetadata, openURL: OpenURLAction) {
    guard let url = URL(string: news.url) else { return }
    let payload = NewsViewPayload(
        newsId: metadata.newsId.flatMap(UUID.init(uuidString:)),
        symbol: metadata.symbol,
        headline: news.title,
        url: news.url
    )
    let service = Container.shared.newsService()
    Task {
        try? await service.recordNewsView(payload: payload)
    }
    openURL(url)
}
