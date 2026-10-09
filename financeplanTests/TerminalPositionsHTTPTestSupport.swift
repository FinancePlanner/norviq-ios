import Foundation
@testable import financeplan

/// Answers requests from a closure. Nonisolated: BaseHTTPClient sends requests
/// from a @concurrent context, so the session witness must not be main-actor-bound.
nonisolated final class TerminalSessionMock: HTTPClientSession, @unchecked Sendable {
  var handler: (@Sendable (URLRequest) throws -> (Data, URLResponse))?
  private(set) var requests: [URLRequest] = []

  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    requests.append(request)
    guard let handler else {
      fatalError("TerminalSessionMock.handler must be configured before use")
    }
    return try handler(request)
  }
}

nonisolated func terminalHTTPResponse(_ request: URLRequest, status: Int, json: String = "") -> (Data, URLResponse) {
  let url = request.url ?? URL(string: "https://api.example.com")!
  let response = HTTPURLResponse(
    url: url,
    statusCode: status,
    httpVersion: nil,
    headerFields: ["Content-Type": "application/json"]
  )!
  return (Data(json.utf8), response)
}

nonisolated func terminalJSONBody(_ request: URLRequest) -> [String: Any]? {
  guard let body = request.httpBody else { return nil }
  return try? JSONSerialization.jsonObject(with: body) as? [String: Any]
}

enum TerminalJSON {
  /// The backend's camelCase shape for the AMZN worked example, 750 shares owned.
  nonisolated static let position = """
  {"id":"p1","ticker":"AMZN","sharesOutstanding":null,"terminalShareCount":11000000000,\
  "terminalMarketCap":10000000000000,"valueWanted":1000000,"sharesOwned":750,\
  "currentSharePrice":null,"notes":null,"sortOrder":0,"terminalSharePrice":909.0909090909091,\
  "sharesNeeded":1100,"capitalAtTodayPrice":null,"progress":0.6818181818181818,\
  "sharesStillNeeded":350,"gapValueAtTerminal":318181.8181818182,"scenarioError":null,\
  "createdAt":"2026-10-09T10:00:00Z","updatedAt":"2026-10-09T10:00:00Z"}
  """
}
