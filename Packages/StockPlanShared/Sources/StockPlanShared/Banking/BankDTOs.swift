import Foundation

/// Aggregator behind a bank connection. Kept provider-agnostic so the clients
/// never hardcode a vendor — the backend picks Plaid (US) or a hosted-redirect
/// aggregator (GoCardless or Enable Banking, EU).
public enum BankProviderKind: String, Codable, Sendable, CaseIterable {
    case plaid
    case gocardless
    case enablebanking
}

/// Lifecycle of a bank connection.
public enum BankConnectionStatus: String, Codable, Sendable, CaseIterable {
    /// Connected and syncing.
    case active
    /// Credentials expired or revoked at the bank; user must re-link.
    case reauthRequired = "reauth_required"
    /// User disconnected, or the item was removed.
    case disconnected
    /// Initial connection attempt failed.
    case error
}

/// How a synced bank transaction maps into the expense flow.
public enum BankTransactionStatus: String, Codable, Sendable, CaseIterable {
    /// Awaiting user review in the suggestions inbox.
    case suggested
    /// Confirmed and turned into an expense.
    case imported
    /// User dismissed it; never becomes an expense.
    case dismissed
}

public struct BankAccountResponse: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let mask: String?
    public let currency: String?
    public let type: String?
    public let balance: Double?

    public init(
        id: String,
        name: String,
        mask: String? = nil,
        currency: String? = nil,
        type: String? = nil,
        balance: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.mask = mask
        self.currency = currency
        self.type = type
        self.balance = balance
    }
}

public struct BankConnectionResponse: Codable, Sendable, Equatable {
    public let id: String
    public let provider: BankProviderKind
    public let institutionName: String?
    public let status: BankConnectionStatus
    public let consentExpiresAt: Date?
    public let lastSyncedAt: Date?
    public let accounts: [BankAccountResponse]

    public init(
        id: String,
        provider: BankProviderKind,
        institutionName: String? = nil,
        status: BankConnectionStatus,
        consentExpiresAt: Date? = nil,
        lastSyncedAt: Date? = nil,
        accounts: [BankAccountResponse] = []
    ) {
        self.id = id
        self.provider = provider
        self.institutionName = institutionName
        self.status = status
        self.consentExpiresAt = consentExpiresAt
        self.lastSyncedAt = lastSyncedAt
        self.accounts = accounts
    }
}

public struct BankTransactionResponse: Codable, Sendable, Equatable {
    public let id: String
    public let accountId: String
    public let amount: Double
    public let currency: String?
    public let date: String // YYYY-MM-DD
    public let merchant: String?
    public let descriptionText: String?
    public let pending: Bool
    public let status: BankTransactionStatus
    public let providerCategory: String?
    /// Set once imported; links to the created expense.
    public let expenseId: String?
    /// True when a matching manual/recurring expense already exists.
    public let possibleDuplicate: Bool

    public init(
        id: String,
        accountId: String,
        amount: Double,
        currency: String? = nil,
        date: String,
        merchant: String? = nil,
        descriptionText: String? = nil,
        pending: Bool = false,
        status: BankTransactionStatus = .suggested,
        providerCategory: String? = nil,
        expenseId: String? = nil,
        possibleDuplicate: Bool = false
    ) {
        self.id = id
        self.accountId = accountId
        self.amount = amount
        self.currency = currency
        self.date = date
        self.merchant = merchant
        self.descriptionText = descriptionText
        self.pending = pending
        self.status = status
        self.providerCategory = providerCategory
        self.expenseId = expenseId
        self.possibleDuplicate = possibleDuplicate
    }
}

/// Response for starting a hosted link flow. For Plaid this carries the
/// `link_token` the LinkKit/Link JS SDK consumes; for GoCardless (Phase 4) it
/// carries a hosted redirect URL. Exactly one of the two is set.
public struct BankLinkSessionResponse: Codable, Sendable, Equatable {
    public let provider: BankProviderKind
    public let linkToken: String?
    public let hostedURL: String?
    public let expiration: Date?

    public init(
        provider: BankProviderKind,
        linkToken: String? = nil,
        hostedURL: String? = nil,
        expiration: Date? = nil
    ) {
        self.provider = provider
        self.linkToken = linkToken
        self.hostedURL = hostedURL
        self.expiration = expiration
    }
}

/// Completes a Plaid Link flow by exchanging the public token for a stored
/// connection.
public struct BankExchangeRequest: Codable, Sendable, Equatable {
    public let publicToken: String
    public let institutionId: String?
    public let institutionName: String?

    public init(publicToken: String, institutionId: String? = nil, institutionName: String? = nil) {
        self.publicToken = publicToken
        self.institutionId = institutionId
        self.institutionName = institutionName
    }
}

/// Confirms a suggested transaction into an expense. The user assigns the
/// pillar and optional category; scanning/import never guesses those.
public struct BankTransactionImportRequest: Codable, Sendable, Equatable {
    public let pillar: BudgetPillar
    public let categoryId: String?
    public let titleOverride: String?

    public init(pillar: BudgetPillar, categoryId: String? = nil, titleOverride: String? = nil) {
        self.pillar = pillar
        self.categoryId = categoryId
        self.titleOverride = titleOverride
    }
}

public struct BankSyncResponse: Codable, Sendable, Equatable {
    public let added: Int
    public let modified: Int
    public let removed: Int

    public init(added: Int = 0, modified: Int = 0, removed: Int = 0) {
        self.added = added
        self.modified = modified
        self.removed = removed
    }
}
