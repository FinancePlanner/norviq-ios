import SwiftUI
import Factory
import StockPlanShared

struct MarketNewsScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    private var newsService: any NewsServicing { Container.shared.newsService() }

    @State private var newsItems: [NewsItemResponse] = []
    @State private var nextCursor: String? = nil
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading && newsItems.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("News Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    }
                } else if newsItems.isEmpty {
                    ContentUnavailableView {
                        Label("No News", systemImage: "newspaper")
                    } description: {
                        Text("Check back later for updates.")
                    }
                } else {
                    // Convert to StockNews for UI reuse
                    let displayNews = newsItems.map { item in
                        StockNews(
                            title: item.headline,
                            url: item.url ?? "",
                            date: item.publishedAt,
                            imageURL: item.imageUrl,
                            source: item.source,
                            summary: item.summary
                        )
                    }
                    StockNewsTab(news: displayNews)
                        .padding(.horizontal, 16)

                    // Infinite scroll trigger
                    if nextCursor != nil && !isLoadingMore {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                Task { await loadMoreIfAvailable() }
                            }
                    }

                    if isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.vertical, 20)
        }
        .refreshable {
            await load(force: true)
        }
        .task {
            await load()
        }
    }

    private func load(force: Bool = false) async {
        if !force, hasLoaded { return }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        nextCursor = nil
        defer { isLoading = false }
        do {
            let result = try await newsService.getNews(limit: 20)
            self.newsItems = result.items
            self.nextCursor = result.nextCursor
            self.hasLoaded = true
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func loadMoreIfAvailable() async {
        guard !isLoadingMore, let cursor = nextCursor else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let result = try await newsService.getNews(cursor: cursor, limit: 20)
            self.newsItems.append(contentsOf: result.items)
            self.nextCursor = result.nextCursor
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
