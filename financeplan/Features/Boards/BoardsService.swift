import Factory
import Foundation
import StockPlanShared

protocol BoardsServicing: Sendable {
  func viewer() async throws -> CommunityViewerStatus
  func acceptGuidelines() async throws
  func block(username: String) async throws
  func boards(cursor: String?) async throws -> BoardListResponse
  func createBoard(_ request: CreateBoardRequest) async throws -> BoardSummary
  func posts(slug: String, sort: BoardPostSort, kind: BoardPostKind?, tag: String?, cursor: String?) async throws -> BoardPostPage
  func createPost(slug: String, _ request: CreateBoardPostRequest) async throws -> BoardPostSummary
  func post(id: UUID) async throws -> BoardPostDetail
  func deletePost(id: UUID) async throws
  func vote(postId: UUID) async throws -> BoardVoteResponse
  func comment(postId: UUID, _ request: CreateBoardCommentRequest) async throws -> BoardComment
  func deleteComment(id: UUID) async throws
  func report(_ request: BoardReportRequest) async throws
  func deleteBoard(slug: String) async throws
  func sanction(_ request: CreateSanctionRequest) async throws -> UserSanction
}

struct DefaultBoardsService: BoardsServicing {
  let client: BoardsHTTPClient

  init(environmentManager: AppEnvironmentManager) {
    self.client = BoardsHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: URLSession.shared,
      authTokenProvider: { await Container.shared.authSessionStore().authToken }
    )
  }

  func viewer() async throws -> CommunityViewerStatus { try await client.viewer() }
  func acceptGuidelines() async throws { try await client.acceptGuidelines() }
  func block(username: String) async throws { try await client.block(username: username) }
  func boards(cursor: String?) async throws -> BoardListResponse { try await client.boards(cursor: cursor) }
  func createBoard(_ request: CreateBoardRequest) async throws -> BoardSummary { try await client.createBoard(request) }
  func posts(slug: String, sort: BoardPostSort, kind: BoardPostKind?, tag: String?, cursor: String?) async throws -> BoardPostPage {
    try await client.posts(slug: slug, sort: sort, kind: kind, tag: tag, cursor: cursor)
  }
  func createPost(slug: String, _ request: CreateBoardPostRequest) async throws -> BoardPostSummary {
    try await client.createPost(slug: slug, request)
  }
  func post(id: UUID) async throws -> BoardPostDetail { try await client.post(id: id) }
  func deletePost(id: UUID) async throws { try await client.deletePost(id: id) }
  func vote(postId: UUID) async throws -> BoardVoteResponse { try await client.vote(postId: postId) }
  func comment(postId: UUID, _ request: CreateBoardCommentRequest) async throws -> BoardComment {
    try await client.comment(postId: postId, request)
  }
  func deleteComment(id: UUID) async throws { try await client.deleteComment(id: id) }
  func report(_ request: BoardReportRequest) async throws { try await client.report(request) }
  func deleteBoard(slug: String) async throws { try await client.deleteBoard(slug: slug) }
  func sanction(_ request: CreateSanctionRequest) async throws -> UserSanction { try await client.sanction(request) }
}
