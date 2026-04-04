import AnyAPI
import Foundation
import StockPlanShared

// MARK: - Market Data Endpoints

struct GetCryptoListEndpoint: Endpoint {
    typealias Response = [CryptoAssetResponse]
    var method: HTTPMethod { .get }
    var path: String { "/v1/crypto/list" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct GetCryptoQuoteEndpoint: Endpoint {
    typealias Response = [CryptoQuoteResponse]
    let symbols: String
    var method: HTTPMethod { .get }
    var path: String { "/v1/crypto/quote/\(symbols.uppercased())" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct GetCryptoBatchQuotesEndpoint: Endpoint {
    typealias Response = [CryptoQuoteShortResponse]
    let short: Bool
    var method: HTTPMethod { .get }
    var path: String { "/v1/crypto/batch-quotes" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        ["short": String(short)]
    }
}

struct GetGeneralCryptoNewsEndpoint: Endpoint {
    typealias Response = [NewsItemResponse]
    var method: HTTPMethod { .get }
    var path: String { "/v1/crypto/news" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

// MARK: - Portfolio Endpoints

struct ListCryptoPortfolioEndpoint: Endpoint {
    typealias Response = [CryptoPortfolioItemResponse]
    var method: HTTPMethod { .get }
    var path: String { "/v1/crypto/portfolio" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct AddToCryptoPortfolioEndpoint: Endpoint {
    typealias Response = CryptoPortfolioItemResponse
    let payload: CryptoPortfolioItemRequest
    var method: HTTPMethod { .post }
    var path: String { "/v1/crypto/portfolio" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        let data = try JSONEncoder.stockPlanShared.encode(payload)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }
}

struct UpdateCryptoPortfolioItemEndpoint: Endpoint {
    typealias Response = CryptoPortfolioItemResponse
    let itemId: String
    let payload: CryptoPortfolioItemRequest
    var method: HTTPMethod { .put }
    var path: String { "/v1/crypto/portfolio/\(itemId)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        let data = try JSONEncoder.stockPlanShared.encode(payload)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }
}

struct RemoveFromCryptoPortfolioEndpoint: Endpoint {
    typealias Response = EmptyResponse
    let itemId: String
    var method: HTTPMethod { .delete }
    var path: String { "/v1/crypto/portfolio/\(itemId)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct EmptyResponse: Codable {}
