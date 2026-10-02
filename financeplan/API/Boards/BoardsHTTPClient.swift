import AnyAPI
import Foundation
import OSLog
import StockPlanShared

nonisolated struct BoardsHTTPClient: Sendable {
  enum Error: HTTPClientError {
    case invalidResponse
    case invalidStatus(Int)
    case unauthorized(String?)
    case api(String)

    nonisolated var errorDescription: String? {
      switch self {
      case .invalidResponse: return "Invalid server response."
      case let .invalidStatus(code): return "Request failed (\(code))."
      case let .unauthorized(message): return message ?? "Your session expired. Please sign in again."
      case let .api(message): return message
      }
    }

    nonisolated var statusCode: Int? {
      if case let .invalidStatus(code) = self { return code }
      return nil
    }

    nonisolated static func == (lhs: Error, rhs: Error) -> Bool {
      switch (lhs, rhs) {
      case (.invalidResponse, .invalidResponse): return true
      case let (.invalidStatus(l), .invalidStatus(r)): return l == r
      case let (.unauthorized(l), .unauthorized(r)): return l == r
      case let (.api(l), .api(r)): return l == r
      default: return false
      }
    }

    static func makeInvalidResponse() -> Error { .invalidResponse }
    static func makeInvalidStatus(_ code: Int) -> Error { .invalidStatus(code) }
    static func makeUnauthorized(_ message: String?) -> Error { .unauthorized(message) }
    static func makeAPI(_ message: String) -> Error { .api(message) }
  }

  private let client: BaseHTTPClient

  init(
    baseURL: URL,
    session: any HTTPClientSession = URLSession.shared,
    authTokenProvider: @escaping @Sendable () async -> String? = { nil }
  ) {
    self.client = BaseHTTPClient(
      baseURL: baseURL,
      session: session,
      authTokenProvider: authTokenProvider,
      logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "BoardsHTTPClient"),
      decoder: .stockPlanShared
    )
  }

  func viewer() async throws -> CommunityViewerStatus {
    try await client.call(GetCommunityViewerEndpoint(), errorType: Error.self)
  }

  func acceptGuidelines() async throws {
    try await client.callWithoutResponse(AcceptCommunityGuidelinesEndpoint(), errorType: Error.self)
  }

  func block(username: String) async throws {
    try await client.callWithoutResponse(BlockCommunityUserEndpoint(username: username), errorType: Error.self)
  }

  func boards(cursor: String?) async throws -> BoardListResponse {
    try await client.call(ListBoardsEndpoint(cursor: cursor), errorType: Error.self)
  }

  func createBoard(_ request: CreateBoardRequest) async throws -> BoardSummary {
    try await client.call(CreateBoardEndpoint(payload: request), errorType: Error.self)
  }

  func posts(
    slug: String, sort: BoardPostSort, kind: BoardPostKind?, tag: String?, cursor: String?
  ) async throws -> BoardPostPage {
    try await client.call(
      ListBoardPostsEndpoint(slug: slug, sort: sort, kind: kind, tag: tag, cursor: cursor),
      errorType: Error.self
    )
  }

  func createPost(slug: String, _ request: CreateBoardPostRequest) async throws -> BoardPostSummary {
    try await client.call(CreateBoardPostEndpoint(slug: slug, payload: request), errorType: Error.self)
  }

  func post(id: UUID) async throws -> BoardPostDetail {
    try await client.call(GetBoardPostEndpoint(postId: id), errorType: Error.self)
  }

  func deletePost(id: UUID) async throws {
    try await client.callWithoutResponse(DeleteBoardPostEndpoint(postId: id), errorType: Error.self)
  }

  func vote(postId: UUID) async throws -> BoardVoteResponse {
    try await client.call(VoteBoardPostEndpoint(postId: postId), errorType: Error.self)
  }

  func comment(postId: UUID, _ request: CreateBoardCommentRequest) async throws -> BoardComment {
    try await client.call(CreateBoardCommentEndpoint(postId: postId, payload: request), errorType: Error.self)
  }

  func deleteComment(id: UUID) async throws {
    try await client.callWithoutResponse(DeleteBoardCommentEndpoint(commentId: id), errorType: Error.self)
  }

  func report(_ request: BoardReportRequest) async throws {
    try await client.callWithoutResponse(ReportBoardContentEndpoint(payload: request), errorType: Error.self)
  }

  func deleteBoard(slug: String) async throws {
    try await client.callWithoutResponse(AdminDeleteBoardEndpoint(slug: slug), errorType: Error.self)
  }

  func sanction(_ request: CreateSanctionRequest) async throws -> UserSanction {
    try await client.call(AdminCreateSanctionEndpoint(payload: request), errorType: Error.self)
  }
}
