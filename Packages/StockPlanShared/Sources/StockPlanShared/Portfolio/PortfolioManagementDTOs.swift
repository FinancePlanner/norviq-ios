import Foundation

public enum PortfolioPurpose: String, Codable, Sendable, CaseIterable {
    case personal
    case retirement
}

public enum PortfolioOwnership: String, Codable, Sendable, CaseIterable {
    case individual
    case joint
}

public enum PortfolioMode: String, Codable, Sendable, CaseIterable {
    case actual
    case hypothetical
}

public enum PortfolioRole: String, Codable, Sendable, CaseIterable {
    case owner
    case editor
}

public enum PortfolioMembershipStatus: String, Codable, Sendable, CaseIterable {
    case invited
    case active
    case revoked
    case left
}

public enum PortfolioInvitationStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case accepted
    case revoked
    case expired
}

public struct PortfolioCapabilities: Codable, Sendable, Equatable {
    public let canView: Bool
    public let canEdit: Bool
    public let canManageMembers: Bool
    public let canManageConnections: Bool
    public let canArchive: Bool
    public let canDelete: Bool

    public init(
        canView: Bool,
        canEdit: Bool,
        canManageMembers: Bool,
        canManageConnections: Bool,
        canArchive: Bool,
        canDelete: Bool
    ) {
        self.canView = canView
        self.canEdit = canEdit
        self.canManageMembers = canManageMembers
        self.canManageConnections = canManageConnections
        self.canArchive = canArchive
        self.canDelete = canDelete
    }
}

public struct Portfolio: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let ownerUserId: String
    public let name: String
    public let purpose: PortfolioPurpose
    public let ownership: PortfolioOwnership
    public let mode: PortfolioMode
    public let baseCurrency: String
    public let isDefault: Bool
    public let sourcePortfolioId: String?
    public let clonedAt: String?
    public let archivedAt: String?
    public let currentUserRole: PortfolioRole
    public let capabilities: PortfolioCapabilities
    public let createdAt: String
    public let updatedAt: String?

    public init(
        id: String,
        ownerUserId: String,
        name: String,
        purpose: PortfolioPurpose,
        ownership: PortfolioOwnership,
        mode: PortfolioMode,
        baseCurrency: String,
        isDefault: Bool,
        sourcePortfolioId: String? = nil,
        clonedAt: String? = nil,
        archivedAt: String? = nil,
        currentUserRole: PortfolioRole,
        capabilities: PortfolioCapabilities,
        createdAt: String,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.name = name
        self.purpose = purpose
        self.ownership = ownership
        self.mode = mode
        self.baseCurrency = baseCurrency
        self.isDefault = isDefault
        self.sourcePortfolioId = sourcePortfolioId
        self.clonedAt = clonedAt
        self.archivedAt = archivedAt
        self.currentUserRole = currentUserRole
        self.capabilities = capabilities
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct PortfolioCreateRequest: Codable, Sendable, Equatable {
    public let name: String
    public let purpose: PortfolioPurpose
    public let ownership: PortfolioOwnership
    public let mode: PortfolioMode
    public let baseCurrency: String
    public let sourcePortfolioId: String?
    public let copyRetirementPlan: Bool

    public init(
        name: String,
        purpose: PortfolioPurpose = .personal,
        ownership: PortfolioOwnership = .individual,
        mode: PortfolioMode = .actual,
        baseCurrency: String,
        sourcePortfolioId: String? = nil,
        copyRetirementPlan: Bool = false
    ) {
        self.name = name
        self.purpose = purpose
        self.ownership = ownership
        self.mode = mode
        self.baseCurrency = baseCurrency
        self.sourcePortfolioId = sourcePortfolioId
        self.copyRetirementPlan = copyRetirementPlan
    }
}

public struct PortfolioUpdateRequest: Codable, Sendable, Equatable {
    public let name: String?
    public let purpose: PortfolioPurpose?
    public let ownership: PortfolioOwnership?
    public let baseCurrency: String?

    public init(
        name: String? = nil,
        purpose: PortfolioPurpose? = nil,
        ownership: PortfolioOwnership? = nil,
        baseCurrency: String? = nil
    ) {
        self.name = name
        self.purpose = purpose
        self.ownership = ownership
        self.baseCurrency = baseCurrency
    }
}

public struct PortfolioCloneRequest: Codable, Sendable, Equatable {
    public let name: String
    public let copyRetirementPlan: Bool

    public init(name: String, copyRetirementPlan: Bool = true) {
        self.name = name
        self.copyRetirementPlan = copyRetirementPlan
    }
}

public struct PortfolioPageResponse: Codable, Sendable, Equatable {
    public let items: [Portfolio]
    public let nextCursor: String?

    public init(items: [Portfolio], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public struct PortfolioMembership: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let portfolioId: String
    public let userId: String
    public let displayName: String
    public let email: String
    public let role: PortfolioRole
    public let status: PortfolioMembershipStatus
    public let joinedAt: String?
    public let createdAt: String

    public init(
        id: String,
        portfolioId: String,
        userId: String,
        displayName: String,
        email: String,
        role: PortfolioRole,
        status: PortfolioMembershipStatus,
        joinedAt: String? = nil,
        createdAt: String
    ) {
        self.id = id
        self.portfolioId = portfolioId
        self.userId = userId
        self.displayName = displayName
        self.email = email
        self.role = role
        self.status = status
        self.joinedAt = joinedAt
        self.createdAt = createdAt
    }
}

public struct PortfolioInvitation: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let portfolioId: String
    public let email: String
    public let role: PortfolioRole
    public let status: PortfolioInvitationStatus
    public let expiresAt: String
    public let acceptedAt: String?
    public let createdAt: String

    public init(
        id: String,
        portfolioId: String,
        email: String,
        role: PortfolioRole = .editor,
        status: PortfolioInvitationStatus,
        expiresAt: String,
        acceptedAt: String? = nil,
        createdAt: String
    ) {
        self.id = id
        self.portfolioId = portfolioId
        self.email = email
        self.role = role
        self.status = status
        self.expiresAt = expiresAt
        self.acceptedAt = acceptedAt
        self.createdAt = createdAt
    }
}

public struct PortfolioInvitationCreateRequest: Codable, Sendable, Equatable {
    public let email: String
    public let role: PortfolioRole

    public init(email: String, role: PortfolioRole = .editor) {
        self.email = email
        self.role = role
    }
}

public struct PortfolioInvitationAcceptRequest: Codable, Sendable, Equatable {
    public let token: String

    public init(token: String) {
        self.token = token
    }
}

public struct PortfolioCashPosition: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let portfolioId: String
    public let label: String
    public let currency: String
    public let balance: Double
    public let asOf: String
    public let createdAt: String
    public let updatedAt: String?

    public init(
        id: String,
        portfolioId: String,
        label: String,
        currency: String,
        balance: Double,
        asOf: String,
        createdAt: String,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.portfolioId = portfolioId
        self.label = label
        self.currency = currency
        self.balance = balance
        self.asOf = asOf
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct PortfolioCashPositionRequest: Codable, Sendable, Equatable {
    public let label: String
    public let currency: String
    public let balance: Double
    public let asOf: String

    public init(label: String, currency: String, balance: Double, asOf: String) {
        self.label = label
        self.currency = currency
        self.balance = balance
        self.asOf = asOf
    }
}

public struct PortfolioAccountAssignmentRequest: Codable, Sendable, Equatable {
    public let portfolioId: String

    public init(portfolioId: String) {
        self.portfolioId = portfolioId
    }
}

public struct PortfolioComparisonHolding: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        symbol
    }

    public let symbol: String
    public let leftValue: Double
    public let rightValue: Double
    public let leftWeightPercent: Double
    public let rightWeightPercent: Double
    public let valueDifference: Double
    public let weightDifferencePercent: Double

    public init(
        symbol: String,
        leftValue: Double,
        rightValue: Double,
        leftWeightPercent: Double,
        rightWeightPercent: Double,
        valueDifference: Double,
        weightDifferencePercent: Double
    ) {
        self.symbol = symbol
        self.leftValue = leftValue
        self.rightValue = rightValue
        self.leftWeightPercent = leftWeightPercent
        self.rightWeightPercent = rightWeightPercent
        self.valueDifference = valueDifference
        self.weightDifferencePercent = weightDifferencePercent
    }
}

public struct PortfolioComparisonColumn: Codable, Sendable, Equatable {
    public let portfolioId: String
    public let name: String
    public let baseCurrency: String
    public let totalValue: Double
    public let cashBalance: Double
    public let holdingCount: Int

    public init(
        portfolioId: String,
        name: String,
        baseCurrency: String,
        totalValue: Double,
        cashBalance: Double,
        holdingCount: Int
    ) {
        self.portfolioId = portfolioId
        self.name = name
        self.baseCurrency = baseCurrency
        self.totalValue = totalValue
        self.cashBalance = cashBalance
        self.holdingCount = holdingCount
    }
}

public struct PortfolioComparison: Codable, Sendable, Equatable {
    public let left: PortfolioComparisonColumn
    public let right: PortfolioComparisonColumn
    public let holdings: [PortfolioComparisonHolding]
    public let generatedAt: String

    public init(
        left: PortfolioComparisonColumn,
        right: PortfolioComparisonColumn,
        holdings: [PortfolioComparisonHolding],
        generatedAt: String
    ) {
        self.left = left
        self.right = right
        self.holdings = holdings
        self.generatedAt = generatedAt
    }
}
