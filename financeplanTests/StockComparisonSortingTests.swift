import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class StockComparisonSortingTests: XCTestCase {

    private enum MockError: Error {
        case notConfigured
    }

    private final class StockServiceMock: StockServicing {
        var fetchStockDetailsResult: Result<StockDetails, Error> = .failure(MockError.notConfigured)
        var fetchStockInsightsResult: Result<StockInsightsResponse, Error> = .failure(MockError.notConfigured)
        
        func fetchStockDetails(stockId: String) async throws -> StockDetails { try fetchStockDetailsResult.get() }
        func updateStock(_ stock: StockResponse, portfolioListId: String?) async throws -> StockResponse { throw MockError.notConfigured }
        func delete(id: String) async throws { throw MockError.notConfigured }
        func sellStock(id: String, request: SellStockRequest) async throws -> StockResponse { throw MockError.notConfigured }
        func createValuation(symbol: String, draft: StockValuationDraft) async throws -> StockValuationRequest { throw MockError.notConfigured }
        func createValuation(symbol: String, bearLow: Double, bearHigh: Double, baseLow: Double, baseHigh: Double, bullLow: Double, bullHigh: Double, rationale: String?, targetDate: String?) async throws -> StockValuationRequest { throw MockError.notConfigured }
        func updateValuation(symbol: String, draft: StockValuationDraft) async throws -> StockValuationRequest { throw MockError.notConfigured }
        func updateValuation(symbol: String, bearLow: Double, bearHigh: Double, baseLow: Double, baseHigh: Double, bullLow: Double, bullHigh: Double, rationale: String?, targetDate: String?) async throws -> StockValuationRequest { throw MockError.notConfigured }
        func getValuation(symbol: String) async throws -> StockValuationRequest { throw MockError.notConfigured }
        func fetchStockInsights(symbol: String) async throws -> StockInsightsResponse { try fetchStockInsightsResult.get() }
        func fetchStockHistory(symbol: String) async throws -> [StockHistory] { [] }
        func fetchStockNews(symbol: String) async throws -> [StockNews] { [] }
        func create(stock: StockRequest, portfolioListId: String?) async throws -> StockResponse { throw MockError.notConfigured }
        func bulkCreate(stocks: [StockRequest]) async throws -> BulkStockResponse { throw MockError.notConfigured }
        func fetchPortfolio(portfolioListId: String?) async throws -> [StockResponse] { [] }
        func fetchPortfolioPerformance(portfolioListId: String?) async throws -> PortfolioPerformanceResponse { throw MockError.notConfigured }
        func fetchPortfolioSummary(portfolioListId: String?) async throws -> PortfolioSummaryResponse { throw MockError.notConfigured }
        func fetchWatchlist(watchlistListId: String?) async throws -> [WatchlistItemResponse] { [] }
        func createWatchlistItem(_ request: WatchlistItemRequest, watchlistListId: String?) async throws -> WatchlistItemResponse { throw MockError.notConfigured }
        func updateWatchlistItem(id: String, request: WatchlistItemUpdateRequest, watchlistListId: String?) async throws -> WatchlistItemResponse { throw MockError.notConfigured }
        func deleteWatchlistItem(id: String) async throws { throw MockError.notConfigured }
        func fetchTargets(symbol: String?) async throws -> [TargetResponse] { [] }
        func createTarget(_ request: TargetRequest) async throws -> TargetResponse { throw MockError.notConfigured }
        func deleteTarget(id: String) async throws { throw MockError.notConfigured }
        func fetchPortfolioLists() async throws -> [PortfolioListDTOResponse] { [] }
        func createPortfolioList(name: String) async throws -> PortfolioListDTOResponse { throw MockError.notConfigured }
        func updatePortfolioList(id: String, name: String) async throws -> PortfolioListDTOResponse { throw MockError.notConfigured }
        func deletePortfolioList(id: String) async throws { throw MockError.notConfigured }
        func fetchWatchlistLists() async throws -> [WatchlistListDTOResponse] { [] }
        func createWatchlistList(name: String) async throws -> WatchlistListDTOResponse { throw MockError.notConfigured }
        func updateWatchlistList(id: String, name: String) async throws -> WatchlistListDTOResponse { throw MockError.notConfigured }
        func deleteWatchlistList(id: String) async throws { throw MockError.notConfigured }
    }

    func testComparisonProfilesOrdering() async throws {
        let mockService = StockServiceMock()
        
        let insights = StockInsightsResponse(
            generatedAt: "2024-01-01T00:00:00Z",
            symbol: "AAPL",
            profile: StockInsightProfileDTO(
                symbol: "AAPL",
                companyName: "Apple",
                currentPrice: 150,
                marketCap: 2.5e12,
                sharesOutstanding: 1.5e10,
                metrics: [:],
                dcfBasePrice: 160,
                dcfBearPrice: 130,
                dcfBullPrice: 190
            ),
            peers: [
                StockInsightPeerDTO(symbol: "MSFT", companyName: "Microsoft", currentPrice: 300, marketCap: 2.3e12, sharesOutstanding: 7e9),
                StockInsightPeerDTO(symbol: "GOOGL", companyName: "Alphabet", currentPrice: 140, marketCap: 1.8e12, sharesOutstanding: 1.2e10)
            ],
            projectionScenarios: []
        )
        
        let stockDetails = StockDetails(
            id: "1",
            symbol: "AAPL",
            shares: 10,
            buyPrice: 140,
            buyDate: "2024-01-01",
            notes: nil,
            portfolioListId: nil
        )
        
        mockService.fetchStockDetailsResult = .success(stockDetails)
        mockService.fetchStockInsightsResult = .success(insights)
        
        let vm = StockDetailsViewModel(service: mockService)
        await vm.load(stockId: "1")
        
        XCTAssertEqual(vm.comparisonProfiles.count, 3)
        XCTAssertEqual(vm.comparisonProfiles[0].symbol, "AAPL")
        XCTAssertEqual(vm.comparisonProfiles[1].symbol, "MSFT")
        XCTAssertEqual(vm.comparisonProfiles[2].symbol, "GOOGL")
    }
}
