import AnyAPI
import Foundation
import StockPlanShared

struct AssistantCreateConversationPayload: Codable, Sendable { let title: String? }
struct AssistantMessagePayload: Codable, Sendable { let content: String }

private func assistantParameters<T: Encodable>(_ value: T) throws -> Parameters {
    let data = try JSONEncoder.stockPlanShared.encode(value)
    return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
}

struct ListAssistantConversationsEndpoint: Endpoint {
    typealias Response = [AIConversationSummaryResponse]
    var method: HTTPMethod { .get }
    var path: String { "/v1/ai/assistant/conversations" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct CreateAssistantConversationEndpoint: Endpoint {
    typealias Response = AIConversationResponse
    let payload: AssistantCreateConversationPayload
    var method: HTTPMethod { .post }
    var path: String { "/v1/ai/assistant/conversations" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { try assistantParameters(payload) }
}

struct GetAssistantConversationEndpoint: Endpoint {
    typealias Response = AIConversationResponse
    let id: String
    var method: HTTPMethod { .get }
    var path: String { "/v1/ai/assistant/conversations/\(id)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct DeleteAssistantConversationEndpoint: Endpoint {
    typealias Response = EmptyAPIResponse
    let id: String
    var method: HTTPMethod { .delete }
    var path: String { "/v1/ai/assistant/conversations/\(id)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct CreateAssistantTurnEndpoint: Endpoint {
    typealias Response = AIAssistantTurnResponse
    let id: String
    let payload: AssistantMessagePayload
    var method: HTTPMethod { .post }
    var path: String { "/v1/ai/assistant/conversations/\(id)/chat" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { try assistantParameters(payload) }
}

struct GetAssistantPreferencesEndpoint: Endpoint {
    typealias Response = AIAssistantPreferencesResponse
    var method: HTTPMethod { .get }
    var path: String { "/v1/ai/assistant/preferences" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct UpdateAssistantPreferencesEndpoint: Endpoint {
    typealias Response = AIAssistantPreferencesResponse
    let payload: AIAssistantPreferencesResponse
    var method: HTTPMethod { .put }
    var path: String { "/v1/ai/assistant/preferences" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { try assistantParameters(payload) }
}

struct ListAssistantTipsEndpoint: Endpoint {
    typealias Response = [AITipResponse]
    var method: HTTPMethod { .get }
    var path: String { "/v1/ai/assistant/tips" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct DismissAssistantTipEndpoint: Endpoint {
    typealias Response = EmptyAPIResponse
    let id: String
    var method: HTTPMethod { .delete }
    var path: String { "/v1/ai/assistant/tips/\(id)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct GetAssistantUsageEndpoint: Endpoint {
    typealias Response = AIAssistantUsageResponse
    var method: HTTPMethod { .get }
    var path: String { "/v1/ai/assistant/usage" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct ListAssistantActionsEndpoint: Endpoint {
    typealias Response = [AIPendingActionResponse]
    var method: HTTPMethod { .get }
    var path: String { "/v1/ai/assistant/actions" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct ConfirmAssistantActionEndpoint: Endpoint {
    typealias Response = AIConfirmedActionResponse
    let id: String
    var method: HTTPMethod { .post }
    var path: String { "/v1/ai/assistant/actions/\(id)/confirm" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct CancelAssistantActionEndpoint: Endpoint {
    typealias Response = EmptyAPIResponse
    let id: String
    var method: HTTPMethod { .post }
    var path: String { "/v1/ai/assistant/actions/\(id)/cancel" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}
