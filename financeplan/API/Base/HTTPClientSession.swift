import Foundation

/// Minimal session protocol abstracting data task execution.
nonisolated public protocol HTTPClientSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClientSession {}
