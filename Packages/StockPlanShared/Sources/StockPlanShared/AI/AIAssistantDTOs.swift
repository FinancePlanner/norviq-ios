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
    /// Whether a turn may attach images. A backend from before images leaves it
    /// out, and absent means no. Clients never send it, so it is nil on the way up.
    public let imagesEnabled: Bool?
    /// The same for PDFs and CSVs: absent means no, and clients never send it.
    public let documentsEnabled: Bool?
    public init(proactiveTipsEnabled: Bool, pushEnabled: Bool, timezone: String, imagesEnabled: Bool? = nil, documentsEnabled: Bool? = nil) {
        self.proactiveTipsEnabled = proactiveTipsEnabled; self.pushEnabled = pushEnabled; self.timezone = timezone
        self.imagesEnabled = imagesEnabled
        self.documentsEnabled = documentsEnabled
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

// MARK: - Trades read from a screenshot (record_trades)

/// A row warning from the backend's preview. A blocking issue such as
/// `already_recorded` means the row cannot be saved as it is.
public struct AITradeIssue: Codable, Sendable, Equatable {
    public let code: String
    public let message: String
    public let blocking: Bool

    public init(code: String, message: String, blocking: Bool) {
        self.code = code; self.message = message; self.blocking = blocking
    }

    private enum CodingKeys: String, CodingKey { case code, message, blocking }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(String.self, forKey: .code) ?? ""
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        blocking = try container.decodeIfPresent(Bool.self, forKey: .blocking) ?? false
    }
}

/// One trade as the model read it, with the preview's issues. `currency`,
/// `fees` and `confidence` may be absent or null; a missing confidence is
/// never high confidence.
public struct AIProposedTrade: Codable, Sendable, Equatable {
    public let symbol: String
    /// `buy` or `sell`.
    public let side: String
    public let quantity: Double
    public let price: Double
    /// `YYYY-MM-DD`, as read. It may not be a real date; the card says so.
    public let tradeDate: String
    public let currency: String?
    public let fees: Double?
    public let confidence: Double?
    public let issues: [AITradeIssue]

    public init(
        symbol: String,
        side: String,
        quantity: Double,
        price: Double,
        tradeDate: String,
        currency: String? = nil,
        fees: Double? = nil,
        confidence: Double? = nil,
        issues: [AITradeIssue] = []
    ) {
        self.symbol = symbol; self.side = side; self.quantity = quantity; self.price = price
        self.tradeDate = tradeDate; self.currency = currency; self.fees = fees
        self.confidence = confidence; self.issues = issues
    }

    private enum CodingKeys: String, CodingKey {
        case symbol, side, quantity, price, currency, fees, confidence, issues
        case tradeDate = "trade_date"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decode(String.self, forKey: .symbol)
        side = try container.decode(String.self, forKey: .side)
        guard side == "buy" || side == "sell" else {
            throw DecodingError.dataCorruptedError(forKey: .side, in: container, debugDescription: "side is \(side)")
        }
        quantity = try container.decode(Double.self, forKey: .quantity)
        price = try container.decode(Double.self, forKey: .price)
        tradeDate = try container.decode(String.self, forKey: .tradeDate)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        fees = try container.decodeIfPresent(Double.self, forKey: .fees)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
        issues = try container.decodeIfPresent([AITradeIssue].self, forKey: .issues) ?? []
    }
}

/// The stored `arguments` of a `record_trades` pending action: the trades
/// card. The keys are snake case on the wire (`proposedTrades` in the
/// backend's `assistant/trades.go`); read it with `decode(arguments:)`.
public struct TradesProposalDTO: Codable, Sendable, Equatable {
    public let portfolioListId: String
    /// Rows left out of the card: options, shorts, dividends or fees.
    public let skippedRows: Int
    public let baseCurrency: String
    /// The proposed portfolio syncs from IBKR, which would overwrite saved trades.
    public let synced: Bool
    public let trades: [AIProposedTrade]

    public init(portfolioListId: String, skippedRows: Int, baseCurrency: String, synced: Bool, trades: [AIProposedTrade]) {
        self.portfolioListId = portfolioListId; self.skippedRows = skippedRows
        self.baseCurrency = baseCurrency; self.synced = synced; self.trades = trades
    }

    private enum CodingKeys: String, CodingKey {
        case synced, trades
        case portfolioListId = "portfolio_list_id"
        case skippedRows = "skipped_rows"
        case baseCurrency = "base_currency"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        portfolioListId = try container.decode(String.self, forKey: .portfolioListId)
        let skipped = try container.decodeIfPresent(Double.self, forKey: .skippedRows) ?? 0
        skippedRows = skipped > 0 && skipped.isFinite ? Int(skipped.rounded(.down)) : 0
        baseCurrency = try container.decodeIfPresent(String.self, forKey: .baseCurrency) ?? ""
        synced = try container.decodeIfPresent(Bool.self, forKey: .synced) ?? false
        trades = try container.decode([AIProposedTrade].self, forKey: .trades)
    }

    /// The card in a pending action's `arguments`, or nil when they cannot be
    /// read or hold no trades; the client then shows its plain card. Uses a
    /// plain decoder: the shared one's snake-case conversion would miss these keys.
    public static func decode(arguments: String) -> TradesProposalDTO? {
        guard let proposal = try? JSONDecoder().decode(TradesProposalDTO.self, from: Data(arguments.utf8)),
              !proposal.trades.isEmpty
        else { return nil }
        return proposal
    }
}

/// One reviewed row of the confirm body. A nil currency or fees is left out.
public struct AIReviewedTrade: Codable, Sendable, Equatable {
    public let symbol: String
    public let side: String
    public let quantity: Double
    public let price: Double
    public let tradeDate: String
    public let currency: String?
    public let fees: Double?

    public init(symbol: String, side: String, quantity: Double, price: Double, tradeDate: String, currency: String? = nil, fees: Double? = nil) {
        self.symbol = symbol; self.side = side; self.quantity = quantity; self.price = price
        self.tradeDate = tradeDate; self.currency = currency; self.fees = fees
    }
}

/// `POST /v1/ai/assistant/actions/:id/confirm` for `record_trades`: only the
/// rows the user kept, as they stand on the card. The keys are camel case;
/// encode with a plain encoder, not the shared snake-case one.
public struct AITradesConfirmRequest: Codable, Sendable, Equatable {
    public let portfolioListId: String
    public let trades: [AIReviewedTrade]

    public init(portfolioListId: String, trades: [AIReviewedTrade]) {
        self.portfolioListId = portfolioListId; self.trades = trades
    }
}

/// One entry of a confirm 422's `rowErrors`. `index` is into the submitted trades.
public struct AITradeRowError: Codable, Sendable, Equatable {
    public let index: Int
    public let code: String
    public let message: String

    public init(index: Int, code: String, message: String) {
        self.index = index; self.code = code; self.message = message
    }
}

/// The 422 body of a refused trades confirm: `{reason, rowErrors}`.
public struct AITradesRefusalResponse: Codable, Sendable, Equatable {
    public let reason: String?
    public let rowErrors: [AITradeRowError]

    public init(reason: String?, rowErrors: [AITradeRowError]) {
        self.reason = reason; self.rowErrors = rowErrors
    }

    private enum CodingKeys: String, CodingKey { case reason, rowErrors }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        rowErrors = (try? container.decodeIfPresent([AITradeRowError].self, forKey: .rowErrors)) ?? []
    }
}
