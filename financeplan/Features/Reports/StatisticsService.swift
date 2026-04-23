import Foundation
import StockPlanShared

protocol StatisticsServicing {
  func fetchStatisticsOverview() async throws -> StatisticsDTO
  func fetchSectorAllocation() async throws -> [SectorAllocationDTO]
  func fetchStockAllocation() async throws -> [StockAllocationDTO]
}

final class StatisticsHTTPService: StatisticsServicing {
  private let environmentManager: AppEnvironmentManager
  private let authSessionManager: AuthSessionManaging

  init(
    environmentManager: AppEnvironmentManager,
    authSessionManager: AuthSessionManaging
  ) {
    self.environmentManager = environmentManager
    self.authSessionManager = authSessionManager
  }

  func fetchStatisticsOverview() async throws -> StatisticsDTO {
    try await performAuthenticated { client in
      try await client.call(GetStatisticsOverviewEndpoint())
    }
  }

  func fetchSectorAllocation() async throws -> [SectorAllocationDTO] {
    try await performAuthenticated { client in
      try await client.call(GetSectorAllocationEndpoint())
    }
  }

  func fetchStockAllocation() async throws -> [StockAllocationDTO] {
    try await performAuthenticated { client in
      try await client.call(GetStockAllocationEndpoint())
    }
  }

  private func makeClient(forceRefresh: Bool = false) async throws -> MarketDataHTTPClient {
    let token = forceRefresh
      ? try await authSessionManager.refreshAccessToken()
      : try await authSessionManager.validAccessToken()

    guard let token else {
      throw AuthSessionError.notAuthenticated
    }

    return MarketDataHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: URLSession.shared,
      authTokenProvider: { token }
    )
  }

  private func performAuthenticated<T>(
    _ operation: (MarketDataHTTPClient) async throws -> T
  ) async throws -> T {
    do {
      let client = try await makeClient()
      return try await operation(client)
    } catch let error as MarketDataHTTPClient.Error where error.isUnauthorized {
      do {
        let client = try await makeClient(forceRefresh: true)
        return try await operation(client)
      } catch let retryError as MarketDataHTTPClient.Error where retryError.isUnauthorized {
        await authSessionManager.invalidateSession()
        throw retryError
      } catch {
        throw error
      }
    }
  }
}

struct StatisticsServiceStub: StatisticsServicing {
  func fetchStatisticsOverview() async throws -> StatisticsDTO {
    StatisticsDTO.empty
  }
  func fetchSectorAllocation() async throws -> [SectorAllocationDTO] {
    []
  }
  func fetchStockAllocation() async throws -> [StockAllocationDTO] {
    []
  }
}

extension StatisticsDTO {
    static var empty: StatisticsDTO {
        StatisticsDTO(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            importedStocks: ImportedStocksStatisticsDTO(
                totalPositions: 0,
                totalMarketValue: 0,
                totalCostBasis: 0,
                totalUnrealizedPnl: 0,
                totalRealizedPnl: 0,
                stockSummaries: [],
                stockAllocations: [],
                sectorAllocations: [],
                calendarPerformance: []
            ),
            watchlist: .init(totalSymbols: 0, symbolsWithNotes: 0, sectorAllocations: [], topWatched: []),
            looklist: .init(totalIdeas: 0, activeIdeas: 0, ideasWithTarget: 0, ideasByConviction: []),
            market: .init(benchmarkSymbol: "SPY", heatmap: [])
        )
    }

#if DEBUG
    static var mock: StatisticsDTO {
        StatisticsDTO(
            generatedAt: "2024-04-05T21:00:00Z",
            importedStocks: ImportedStocksStatisticsDTO(
                totalPositions: 5,
                totalMarketValue: 124830.42,
                totalCostBasis: 115000.0,
                totalUnrealizedPnl: 9830.42,
                totalRealizedPnl: 2500.0,
                stockSummaries: [],
                stockAllocations: [
                    .init(symbol: "AAPL", value: 45000, weightPercent: 36),
                    .init(symbol: "MSFT", value: 35000, weightPercent: 28),
                    .init(symbol: "GOOGL", value: 20000, weightPercent: 16),
                    .init(symbol: "AMZN", value: 15000, weightPercent: 12),
                    .init(symbol: "TSLA", value: 9830.42, weightPercent: 8)
                ],
                sectorAllocations: [
                    .init(sector: "Technology", value: 80000, weightPercent: 64),
                    .init(sector: "Consumer Cyclical", value: 24830.42, weightPercent: 20),
                    .init(sector: "Communication Services", value: 20000, weightPercent: 16)
                ],
                calendarPerformance: []
            ),
            watchlist: .init(totalSymbols: 10, symbolsWithNotes: 5, sectorAllocations: [], topWatched: []),
            looklist: .init(totalIdeas: 3, activeIdeas: 2, ideasWithTarget: 2, ideasByConviction: []),
            market: .init(benchmarkSymbol: "SPY", heatmap: [])
        )
    }
#endif
}
