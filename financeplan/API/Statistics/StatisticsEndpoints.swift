import AnyAPI
import Foundation
import StockPlanShared

nonisolated struct GetStatisticsOverviewEndpoint: Endpoint {
  typealias Response = StatisticsDTO

  var method: HTTPMethod { .get }
  var path: String { "/v1/statistics/overview" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetSectorAllocationEndpoint: Endpoint {
  typealias Response = [SectorAllocationDTO]

  var method: HTTPMethod { .get }
  var path: String { "/v1/statistics/stocks/sector-allocation" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetSectorGainsEndpoint: Endpoint {
  typealias Response = SectorGainsResponse

  var method: HTTPMethod { .get }
  var path: String { "/v1/statistics/stocks/sector-gains" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetStockAllocationEndpoint: Endpoint {
  typealias Response = [StockAllocationDTO]

  var method: HTTPMethod { .get }
  var path: String { "/v1/statistics/stocks/allocation" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}
