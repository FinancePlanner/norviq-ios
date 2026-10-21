import Foundation
import StockPlanShared

/// One parsed line of a server-sent-events stream.
nonisolated enum SSELine: Equatable, Sendable {
  /// A complete frame: the last `event:` name seen (default `message`) and
  /// this `data:` line's payload.
  case frame(event: String, data: String)
  /// `retry:`, the reconnect delay the server asks for.
  case retry(milliseconds: Int)
  /// A `:` comment; the server's heartbeat.
  case comment
}

/// Line-at-a-time SSE parser. `URLSession.AsyncBytes.lines` never yields the
/// blank line that ends a frame, so this dispatches on every `data:` line
/// instead of waiting for one. The server writes one `data:` line per frame,
/// which makes that exact.
nonisolated struct SSELineParser: Sendable {
  private(set) var event = "message"

  mutating func consume(_ rawLine: String) -> SSELine? {
    // `lines` already strips the terminator; a stray CR from a CRLF stream
    // must not end up in the event name.
    let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine
    if line.isEmpty {
      event = "message"
      return nil
    }
    if line.hasPrefix(":") { return .comment }
    let (field, value) = Self.split(line)
    switch field {
    case "event":
      event = value.isEmpty ? "message" : value
      return nil
    case "data":
      let frame = SSELine.frame(event: event, data: value)
      event = "message"
      return frame
    case "retry":
      return Int(value).map { .retry(milliseconds: $0) }
    default:
      // `id:` and unknown fields: no replay here, so nothing to keep.
      return nil
    }
  }

  /// `field: value`, with the single optional space after the colon removed.
  private static func split(_ line: String) -> (String, String) {
    guard let colon = line.firstIndex(of: ":") else { return (line, "") }
    var value = line[line.index(after: colon)...]
    if value.first == " " { value = value.dropFirst() }
    return (String(line[..<colon]), String(value))
  }
}

/// What the live stream yields to `GroupsStore`.
nonisolated enum GroupsRealtimeSignal: Sendable, Equatable {
  case event(GroupRealtimeEvent)
  case retry(milliseconds: Int)
}

/// `GET /v1/realtime/stream`: one SSE stream per signed-in client. Sending
/// stays on REST; the stream only announces what REST committed. There is no
/// replay: every connection opens with `ready`, and the store catches up over
/// REST then.
nonisolated struct GroupsRealtimeClient: Sendable {
  enum Failure: LocalizedError, Equatable {
    case invalidResponse
    case unauthorized
    /// 404: Groups is switched off, or the account can't use the community.
    /// Reconnecting won't help until something changes.
    case unavailable
    case server(Int)

    var errorDescription: String? {
      switch self {
      case .invalidResponse: "The live connection returned an unexpected response."
      case .unauthorized: "Please sign in again."
      case .unavailable: "Groups aren't available right now."
      case let .server(code): "The live connection failed (\(code))."
      }
    }

    /// Worth trying again later. A 401 or 404 isn't.
    var isRetryable: Bool {
      switch self {
      case .unauthorized, .unavailable: false
      case .invalidResponse, .server: true
      }
    }
  }

  let baseURL: URL
  let session: URLSession
  let authTokenProvider: @Sendable () async -> String?

  init(
    baseURL: URL,
    session: URLSession = GroupsRealtimeClient.streamingSession,
    authTokenProvider: @escaping @Sendable () async -> String? = { nil }
  ) {
    self.baseURL = baseURL
    self.session = session
    self.authTokenProvider = authTokenProvider
  }

  /// The server pings every 20 seconds and closes after 10 minutes, so a
  /// minute of silence means the connection is dead.
  static let streamingSession: URLSession = {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 60
    configuration.timeoutIntervalForResource = 15 * 60
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    return URLSession(configuration: configuration)
  }()

  /// Ends when the server closes the stream (after `reconnect`, a deploy, or
  /// the 10-minute cap); the caller reconnects.
  func connect() -> AsyncThrowingStream<GroupsRealtimeSignal, Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        do {
          var request = URLRequest(url: baseURL.appendingPathComponent("v1/realtime/stream"))
          request.httpMethod = "GET"
          request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
          if let token = await authTokenProvider(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
          }
          let (bytes, response) = try await session.bytes(for: ClientCapabilities.applied(to: request))
          guard let http = response as? HTTPURLResponse else { throw Failure.invalidResponse }
          switch http.statusCode {
          case 200: break
          case 401: throw Failure.unauthorized
          case 403, 404: throw Failure.unavailable
          default: throw Failure.server(http.statusCode)
          }

          var parser = SSELineParser()
          for try await line in bytes.lines {
            switch parser.consume(line) {
            case let .frame(_, data):
              if let event = Self.decode(data) { continuation.yield(.event(event)) }
            case let .retry(milliseconds):
              continuation.yield(.retry(milliseconds: milliseconds))
            case .comment, nil:
              continue
            }
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  /// The payload carries its own `type`, so the `event:` name isn't needed.
  /// A frame this app can't read is skipped rather than ending the stream.
  static func decode(_ data: String) -> GroupRealtimeEvent? {
    guard let bytes = data.data(using: .utf8) else { return nil }
    return try? JSONDecoder.stockPlanShared.decode(GroupRealtimeEvent.self, from: bytes)
  }
}
