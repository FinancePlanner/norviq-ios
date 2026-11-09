import AnyAPI
import Foundation
import OSLog
import StockPlanShared

nonisolated struct PersistentAssistantHTTPClient: Sendable {
    enum Error: HTTPClientError {
        case invalidResponse
        case invalidStatus(Int)
        case unauthorized(String?)
        case api(String)
        /// 409: e.g. confirming an action that is no longer pending.
        case conflict(String?)
        /// 422, with the trades card's row errors when the body carries them.
        case unprocessable(reason: String?, rowErrors: [AITradeRowError])
        /// 422 from a holdings confirm that names a collision or rows (`rows`, not `rowErrors`).
        case holdingsRefused(AIHoldingsRefusalResponse)
        /// 403 `upgrade_required`, with the body's `error`.
        case upgradeRequired(String?)

        nonisolated var errorDescription: String? {
            switch self {
            case .invalidResponse: return "Invalid server response."
            case let .invalidStatus(code): return "Request failed (\(code))."
            case let .unauthorized(message): return message ?? "Your session expired. Please sign in again."
            case let .api(message): return message
            case let .conflict(message): return message ?? "This was already done."
            case let .unprocessable(reason, _): return reason ?? "Request failed (422)."
            case let .holdingsRefused(refusal): return refusal.reason ?? "Request failed (422)."
            case let .upgradeRequired(message): return message ?? "This is part of Pro."
            }
        }

        nonisolated var statusCode: Int? {
            switch self {
            case let .invalidStatus(code): code
            case .conflict: 409
            case .unprocessable, .holdingsRefused: 422
            case .upgradeRequired: 403
            default: nil
            }
        }

        static func makeInvalidResponse() -> Error { .invalidResponse }
        static func makeInvalidStatus(_ code: Int) -> Error { .invalidStatus(code) }
        static func makeUnauthorized(_ message: String?) -> Error { .unauthorized(message) }
        static func makeAPI(_ message: String) -> Error { .api(message) }
        static func makeStatus(_ code: Int, message: String?) -> Error {
            if code == 409 { return .conflict(message) }
            if let message, !message.isEmpty { return .api(message) }
            return .invalidStatus(code)
        }

        /// Keeps a trades confirm's 422 row errors and a 403 `upgrade_required`,
        /// which the trades card answers differently from other failures.
        static func makeStatus(_ code: Int, message: String?, body: Data) -> Error {
            switch code {
            case 422:
                // A holdings confirm answers with `code`/`rows`; the trades one with `rowErrors`.
                if let holdings = try? JSONDecoder().decode(AIHoldingsRefusalResponse.self, from: body),
                   holdings.code == AIHoldingsRefusalResponse.collisionCode || !holdings.rows.isEmpty {
                    return .holdingsRefused(AIHoldingsRefusalResponse(
                        reason: holdings.reason.flatMap { $0.isEmpty ? nil : $0 } ?? message,
                        code: holdings.code, symbols: holdings.symbols, rows: holdings.rows
                    ))
                }
                let refusal = try? JSONDecoder().decode(AITradesRefusalResponse.self, from: body)
                let reason = refusal?.reason.flatMap { $0.isEmpty ? nil : $0 } ?? message
                return .unprocessable(reason: reason, rowErrors: refusal?.rowErrors ?? [])
            case 403:
                if let billing = try? JSONDecoder().decode(UpgradeRequiredBody.self, from: body),
                   billing.code == "upgrade_required" {
                    return .upgradeRequired(billing.error ?? message)
                }
            default:
                break
            }
            return makeStatus(code, message: message)
        }
    }

    /// `{"success":false,"code":"upgrade_required","error":…}`, the fields read here.
    nonisolated private struct UpgradeRequiredBody: Decodable {
        let code: String?
        let error: String?
    }

    private let client: BaseHTTPClient

    init(
        baseURL: URL,
        session: any HTTPClientSession = URLSession.shared,
        authTokenProvider: @escaping @Sendable () async -> String? = { nil }
    ) {
        client = BaseHTTPClient(
            baseURL: baseURL,
            session: session,
            authTokenProvider: authTokenProvider,
            logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "PersistentAssistantHTTPClient"),
            decoder: .stockPlanShared
        )
    }

    func conversations() async throws -> [AIConversationSummaryResponse] {
        try await client.call(ListAssistantConversationsEndpoint(), errorType: Error.self)
    }

    func createConversation(title: String?, bindMessaging: Bool? = nil) async throws -> AIConversationResponse {
        try await client.call(CreateAssistantConversationEndpoint(payload: .init(title: title, bindMessaging: bindMessaging)), errorType: Error.self)
    }

    func conversation(id: String) async throws -> AIConversationResponse {
        try await client.call(GetAssistantConversationEndpoint(id: id), errorType: Error.self)
    }

    func deleteConversation(id: String) async throws {
        try await client.callWithoutResponse(DeleteAssistantConversationEndpoint(id: id), errorType: Error.self)
    }

    func turn(conversationID: String, content: String) async throws -> AIAssistantTurnResponse {
        try await client.call(CreateAssistantTurnEndpoint(id: conversationID, payload: .init(content: content)), errorType: Error.self)
    }

    func preferences() async throws -> AIAssistantPreferencesResponse {
        try await client.call(GetAssistantPreferencesEndpoint(), errorType: Error.self)
    }

    func updatePreferences(_ payload: AIAssistantPreferencesResponse) async throws -> AIAssistantPreferencesResponse {
        try await client.call(UpdateAssistantPreferencesEndpoint(payload: payload), errorType: Error.self)
    }

    func tips() async throws -> [AITipResponse] {
        try await client.call(ListAssistantTipsEndpoint(), errorType: Error.self)
    }

    func dismissTip(id: String) async throws {
        try await client.callWithoutResponse(DismissAssistantTipEndpoint(id: id), errorType: Error.self)
    }

    func usage() async throws -> AIAssistantUsageResponse {
        try await client.call(GetAssistantUsageEndpoint(), errorType: Error.self)
    }

    func pendingActions() async throws -> [AIPendingActionResponse] {
        try await client.call(ListAssistantActionsEndpoint(), errorType: Error.self)
    }

    func confirmAction(id: String) async throws -> AIConfirmedActionResponse {
        try await client.call(ConfirmAssistantActionEndpoint(id: id), errorType: Error.self)
    }

    func confirmTrades(id: String, portfolioListID: String, trades: [AIReviewedTrade]) async throws -> AIConfirmedActionResponse {
        try await client.call(
            ConfirmAssistantTradesEndpoint(id: id, payload: .init(portfolioListId: portfolioListID, trades: trades)),
            errorType: Error.self
        )
    }

    func confirmHoldings(id: String, body: AIReviewedHoldings) async throws -> AIConfirmedActionResponse {
        try await client.call(ConfirmAssistantHoldingsEndpoint(id: id, payload: body), errorType: Error.self)
    }

    func cancelAction(id: String) async throws {
        try await client.callWithoutResponse(CancelAssistantActionEndpoint(id: id), errorType: Error.self)
    }

    /// The portfolios a trades card can save to.
    func portfolioLists() async throws -> [PortfolioListDTOResponse] {
        try await client.call(GetPortfolioListsEndpoint(), errorType: Error.self)
    }

    func memos(bookmarked: Bool?, conversationID: String?) async throws -> [PositionMemoListItem] {
        try await client.call(ListPositionMemosEndpoint(bookmarked: bookmarked, conversationID: conversationID), errorType: Error.self)
    }

    func memo(id: String) async throws -> PositionMemoDetail {
        try await client.call(GetPositionMemoEndpoint(id: id), errorType: Error.self)
    }

    func bookmarkMemo(id: String, bookmarked: Bool) async throws -> PositionMemoCard {
        try await client.call(
            BookmarkPositionMemoEndpoint(id: id, payload: .init(bookmarked: bookmarked)),
            errorType: Error.self
        )
    }

    func deleteMemo(id: String) async throws {
        try await client.callWithoutResponse(DeletePositionMemoEndpoint(id: id), errorType: Error.self)
    }
}

nonisolated extension PersistentAssistantHTTPClient.Error: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse): true
        case let (.invalidStatus(lhs), .invalidStatus(rhs)): lhs == rhs
        case let (.unauthorized(lhs), .unauthorized(rhs)): lhs == rhs
        case let (.api(lhs), .api(rhs)): lhs == rhs
        case let (.conflict(lhs), .conflict(rhs)): lhs == rhs
        case let (.unprocessable(lr, le), .unprocessable(rr, re)): lr == rr && le == re
        case let (.holdingsRefused(lhs), .holdingsRefused(rhs)): lhs == rhs
        case let (.upgradeRequired(lhs), .upgradeRequired(rhs)): lhs == rhs
        default: false
        }
    }
}
