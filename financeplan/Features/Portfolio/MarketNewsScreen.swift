import SwiftUI
import Factory
import StockPlanShared

struct MarketNewsScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    private var marketDataService: any MarketDataServicing { Container.shared.marketDataService() }
    
    @State private var news: [StockNews] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasLoadedNews = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading && news.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("News Error", systemImage: "newspaper.fill")
                    } description: {
                        Text(errorMessage)
                    }
                } else if news.isEmpty {
                    ContentUnavailableView {
                        Label("No Market News", systemImage: "newspaper")
                    } description: {
                        Text("Check back later for the latest market shifts.")
                    }
                } else {
                    StockNewsTab(news: news)
                        .padding(.horizontal, 16)
                }
                
                Spacer(minLength: 40)
            }
            .padding(.vertical, 20)
        }
        .refreshable {
            await loadNews(force: true)
        }
        .task {
            await loadNews()
        }
    }

    private func loadNews(force: Bool = false) async {
        if !force, hasLoadedNews { return }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            self.news = try await marketDataService.fetchMarketNews(limit: 20)
            hasLoadedNews = true
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
