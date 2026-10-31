import Foundation

public enum AIAssistantRole: String, Codable, Sendable { case user, assistant, tool }
public enum AIActionStatus: String, Codable, Sendable { case pending, confirmed, completed, cancelled, expired, failed }

public struct AIConversationSummaryResponse: Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let lastMessagePreview: String?
    public let createdAt: String
    public let updatedAt: String
    public init(id: String, title: String, lastMessagePreview: String?, createdAt: String, updatedAt: String) {
        self.id = id; self.title = title; self.lastMessagePreview = lastMessagePreview
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

/// Why an assistant message exists. `reply` answers something the user sent;
/// `proactive` was posted by the server on its own (a standing task, a daily
/// tip) and is rendered with a caption from `sourceLabel`.
public enum AIMessageOrigin: String, Codable, Sendable {
    case reply
    case proactive
}

public struct AIMessageResponse: Codable, Sendable, Equatable {
    public let id: String
    public let conversationId: String
    public let role: AIAssistantRole
    public let content: String
    public let createdAt: String
    /// Absent on servers older than 5.12.0 and on user messages; clients treat
    /// a missing value as `reply`.
    public let origin: AIMessageOrigin?
    /// Caption shown above a proactive bubble, e.g. "Standing task", "Daily tip".
    public let sourceLabel: String?

    public init(
        id: String,
        conversationId: String,
        role: AIAssistantRole,
        content: String,
        createdAt: String,
        origin: AIMessageOrigin? = nil,
        sourceLabel: String? = nil
    ) {
        self.id = id; self.conversationId = conversationId; self.role = role
        self.content = content; self.createdAt = createdAt
        self.origin = origin; self.sourceLabel = sourceLabel
    }

    private enum CodingKeys: String, CodingKey {
        case id, conversationId, role, content, createdAt, origin, sourceLabel
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        conversationId = try container.decode(String.self, forKey: .conversationId)
        role = try container.decode(AIAssistantRole.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        // Lenient: an origin this client does not know yet reads as absent
        // rather than failing the whole conversation.
        origin = (try? container.decodeIfPresent(String.self, forKey: .origin)).flatMap(AIMessageOrigin.init(rawValue:))
        sourceLabel = try container.decodeIfPresent(String.self, forKey: .sourceLabel)
    }
}

public struct AIConversationResponse: Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let messages: [AIMessageResponse]
    public let createdAt: String
    public let updatedAt: String
    public init(id: String, title: String, messages: [AIMessageResponse], createdAt: String, updatedAt: String) {
        self.id = id; self.title = title; self.messages = messages
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

public struct AIAssistantPreferencesResponse: Codable, Sendable, Equatable {
    public let proactiveTipsEnabled: Bool
    public let pushEnabled: Bool
    public let timezone: String
    public init(proactiveTipsEnabled: Bool, pushEnabled: Bool, timezone: String) {
        self.proactiveTipsEnabled = proactiveTipsEnabled; self.pushEnabled = pushEnabled; self.timezone = timezone
    }
}

public struct AIAssistantUsageResponse: Codable, Sendable, Equatable {
    public let month: String
    public let used: Int
    public let limit: Int?
    public let remaining: Int?
    public let isPro: Bool
    public init(month: String, used: Int, limit: Int?, remaining: Int?, isPro: Bool) {
        self.month = month; self.used = used; self.limit = limit; self.remaining = remaining; self.isPro = isPro
    }
}

public struct AITipResponse: Codable, Sendable, Equatable {
    public let id: String
    public let kind: String
    public let title: String
    public let body: String
    public let importance: Int
    public let actionPath: String?
    public let createdAt: String
    public let expiresAt: String
    public init(
        id: String,
        kind: String,
        title: String,
        body: String,
        importance: Int,
        actionPath: String?,
        createdAt: String,
        expiresAt: String
    ) {
        self.id = id; self.kind = kind; self.title = title; self.body = body; self.importance = importance
        self.actionPath = actionPath; self.createdAt = createdAt; self.expiresAt = expiresAt
    }
}

public struct AIPendingActionResponse: Codable, Sendable, Equatable {
    public let id: String
    public let conversationId: String?
    public let toolName: String
    public let summary: String
    public let arguments: String
    public let status: AIActionStatus
    public let expiresAt: String
    public let createdAt: String
    public init(
        id: String,
        conversationId: String?,
        toolName: String,
        summary: String,
        arguments: String,
        status: AIActionStatus,
        expiresAt: String,
        createdAt: String
    ) {
        self.id = id; self.conversationId = conversationId; self.toolName = toolName
        self.summary = summary; self.arguments = arguments; self.status = status
        self.expiresAt = expiresAt; self.createdAt = createdAt
    }
}

/// A standing task the assistant offers to create. Travels with a pending
/// action whose `toolName` is `create_watch`; confirming that action (the
/// existing confirm/cancel routes) creates the watch.
public struct AIWatchProposalResponse: Codable, Sendable, Equatable {
    public let title: String
    /// Human schedule, e.g. "Every day at 8:00" or "Every hour".
    public let scheduleHuman: String
    public let intervalMinutes: Int
    /// What the assistant will check on each run.
    public let spec: String

    public init(title: String, scheduleHuman: String, intervalMinutes: Int, spec: String) {
        self.title = title; self.scheduleHuman = scheduleHuman
        self.intervalMinutes = intervalMinutes; self.spec = spec
    }
}

public enum AIAssistantTurnKind: String, Codable, Sendable {
    case message
    case confirmationRequired = "confirmation_required"
}

public struct AIAssistantTurnResponse: Codable, Sendable, Equatable {
    public let kind: AIAssistantTurnKind
    public let conversationId: String
    public let message: AIMessageResponse
    public let pendingAction: AIPendingActionResponse?
    /// Present when this turn wrote a position memo. The message text stays a one-line card.
    public let memo: PositionMemoCard?
    /// Present when the turn proposes a standing task. `pendingAction` is then
    /// the `create_watch` action to confirm or cancel.
    public let watchProposal: AIWatchProposalResponse?

    public init(
        kind: AIAssistantTurnKind,
        conversationId: String,
        message: AIMessageResponse,
        pendingAction: AIPendingActionResponse?,
        memo: PositionMemoCard? = nil,
        watchProposal: AIWatchProposalResponse? = nil
    ) {
        self.kind = kind
        self.conversationId = conversationId
        self.message = message
        self.pendingAction = pendingAction
        self.memo = memo
        self.watchProposal = watchProposal
    }
}

public struct AIConfirmedActionResponse: Codable, Sendable, Equatable {
    public let actionId: String
    public let status: AIActionStatus
    public let resultId: String?
    public let message: String

    public init(actionId: String, status: AIActionStatus, resultId: String?, message: String) {
        self.actionId = actionId
        self.status = status
        self.resultId = resultId
        self.message = message
    }
}
