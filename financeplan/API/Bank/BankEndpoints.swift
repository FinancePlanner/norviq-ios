import AnyAPI
import Foundation
import StockPlanShared

struct CreateBankLinkSessionEndpoint: Endpoint {
  typealias Response = BankLinkSessionResponse

  var method: HTTPMethod { .post }
  var path: String { "/v1/banks/link-session" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct ExchangeBankConnectionEndpoint: Endpoint {
  typealias Response = BankConnectionResponse

  let publicToken: String
  let institutionId: String?
  let institutionName: String?

  var method: HTTPMethod { .post }
  var path: String { "/v1/banks/connections" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var params: Parameters = ["publicToken": publicToken]
    if let institutionId { params["institutionId"] = institutionId }
    if let institutionName { params["institutionName"] = institutionName }
    return params
  }
}

/// Placeholder response for endpoints that return 204 No Content.
struct EmptyBankResponse: Codable, Sendable {}

struct ListBankInstitutionsEndpoint: Endpoint {
  typealias Response = [BankInstitutionResponse]

  let country: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/banks/institutions?provider=gocardless&country=\(country)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct CreateBankHostedLinkEndpoint: Endpoint {
  typealias Response = BankLinkSessionResponse

  let institutionId: String
  let redirectURI: String

  var method: HTTPMethod { .post }
  var path: String { "/v1/banks/link-session?provider=gocardless" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["institutionId": institutionId, "redirectURI": redirectURI]
  }
}

struct DisconnectBankConnectionEndpoint: Endpoint {
  typealias Response = EmptyBankResponse

  let connectionId: String

  var method: HTTPMethod { .delete }
  var path: String { "/v1/banks/connections/\(connectionId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct DismissBankTransactionEndpoint: Endpoint {
  typealias Response = EmptyBankResponse

  let transactionId: String

  var method: HTTPMethod { .post }
  var path: String { "/v1/banks/transactions/\(transactionId)/dismiss" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct ListBankConnectionsEndpoint: Endpoint {
  typealias Response = [BankConnectionResponse]

  var method: HTTPMethod { .get }
  var path: String { "/v1/banks/connections" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct SyncBankConnectionEndpoint: Endpoint {
  typealias Response = BankSyncResponse

  let connectionId: String

  var method: HTTPMethod { .post }
  var path: String { "/v1/banks/connections/\(connectionId)/sync" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct ListBankTransactionsEndpoint: Endpoint {
  typealias Response = [BankTransactionResponse]

  let status: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/banks/transactions?status=\(status)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct ImportBankTransactionEndpoint: Endpoint {
  typealias Response = ExpenseResponse

  let transactionId: String
  let pillar: BudgetPillar
  let categoryId: String?
  let titleOverride: String?

  var method: HTTPMethod { .post }
  var path: String { "/v1/banks/transactions/\(transactionId)/import" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var params: Parameters = ["pillar": pillar.rawValue]
    if let categoryId { params["categoryId"] = categoryId }
    if let titleOverride { params["titleOverride"] = titleOverride }
    return params
  }
}
