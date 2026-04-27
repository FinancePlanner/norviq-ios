import Foundation

/// Minimal session protocol abstracting data task execution.
public protocol HTTPClientSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClientSession {}

// Extend custom URLSessionProtocols from each API module to conform to HTTPClientSession.
// These protocols are defined across the codebase; adding conformance here centralizes it.

//extension AuthURLSessionProtocol: HTTPClientSession {}
//extension BrokerURLSessionProtocol: HTTPClientSession {}
//extension MarketDataURLSessionProtocol: HTTPClientSession {}
//extension StockURLSessionProtocol: HTTPClientSession {}
//extension UserProfileURLSessionProtocol: HTTPClientSession {}
//extension BillingURLSessionProtocol: HTTPClientSession {}
//extension ActivityURLSessionProtocol: HTTPClientSession {}
//extension PushNotificationsURLSessionProtocol: HTTPClientSession {}
// Crypto uses MarketDataURLSessionProtocol already handled.
// Dashboard, Expenses, Goals, News, Badges use URLSession directly — no additional extension needed.
