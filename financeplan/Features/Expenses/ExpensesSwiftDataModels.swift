import Foundation
import SwiftData
import StockPlanShared

@Model
final class LocalExpense {
    @Attribute(.unique)
    var id: UUID
    var title: String
    var amount: Double
    var pillarRawValue: String
    var occurredOn: Date
    var linkedPlanItemId: UUID?
    var categoryId: String?
    var splitModeRawValue: String
    var userSharePercent: Double
    
    // Optional Foreign Currency fields
    var foreignAmount: Double?
    var foreignCurrency: String?
    var exchangeRate: Double?
    
    // Metadata for syncing
    var lastUpdated: Date
    var isPendingSync: Bool

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        pillar: BudgetPillar,
        occurredOn: Date,
        linkedPlanItemId: UUID? = nil,
        categoryId: String? = nil,
        splitMode: ExpenseSplitMode = .personal,
        userSharePercent: Double = 100,
        foreignAmount: Double? = nil,
        foreignCurrency: String? = nil,
        exchangeRate: Double? = nil,
        lastUpdated: Date = .now,
        isPendingSync: Bool = false
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.pillarRawValue = pillar.rawValue
        self.occurredOn = occurredOn
        self.linkedPlanItemId = linkedPlanItemId
        self.categoryId = categoryId
        self.splitModeRawValue = splitMode.rawValue
        self.userSharePercent = userSharePercent
        self.foreignAmount = foreignAmount
        self.foreignCurrency = foreignCurrency
        self.exchangeRate = exchangeRate
        self.lastUpdated = lastUpdated
        self.isPendingSync = isPendingSync
    }
    
    var pillar: BudgetPillar {
        BudgetPillar(rawValue: pillarRawValue) ?? .fundamentals
    }
    
    var splitMode: ExpenseSplitMode {
        ExpenseSplitMode(rawValue: splitModeRawValue) ?? .personal
    }
}

@Model
final class LocalBudgetSnapshot {
    @Attribute(.unique)
    var id: UUID
    var monthStart: Date
    var netSalary: Double
    var targetSharesRaw: [String: Double]
    var lastUpdated: Date
    var isPendingSync: Bool

    @Relationship(deleteRule: .cascade, inverse: \LocalBudgetPlanItem.snapshot)
    var items: [LocalBudgetPlanItem] = []

    init(
        id: UUID = UUID(),
        monthStart: Date,
        netSalary: Double,
        targetShares: [BudgetPillar: Double],
        lastUpdated: Date = .now,
        isPendingSync: Bool = false
    ) {
        self.id = id
        self.monthStart = monthStart
        self.netSalary = netSalary
        var raw: [String: Double] = [:]
        for (k, v) in targetShares { raw[k.rawValue] = v }
        self.targetSharesRaw = raw
        self.lastUpdated = lastUpdated
        self.isPendingSync = isPendingSync
    }
    
    var targetShares: [BudgetPillar: Double] {
        var shares: [BudgetPillar: Double] = [:]
        for (k, v) in targetSharesRaw {
            if let p = BudgetPillar(rawValue: k) {
                shares[p] = v
            }
        }
        return shares
    }
}

@Model
final class LocalBudgetPlanItem {
    @Attribute(.unique)
    var id: UUID
    var title: String
    var plannedAmount: Double
    var pillarRawValue: String
    var categoryId: String?
    var splitModeRawValue: String
    var userSharePercent: Double
    var lastUpdated: Date
    var isPendingSync: Bool
    
    var snapshot: LocalBudgetSnapshot?

    init(
        id: UUID = UUID(),
        title: String,
        plannedAmount: Double,
        pillar: BudgetPillar,
        categoryId: String? = nil,
        splitMode: ExpenseSplitMode = .personal,
        userSharePercent: Double = 100,
        lastUpdated: Date = .now,
        isPendingSync: Bool = false
    ) {
        self.id = id
        self.title = title
        self.plannedAmount = plannedAmount
        self.pillarRawValue = pillar.rawValue
        self.categoryId = categoryId
        self.splitModeRawValue = splitMode.rawValue
        self.userSharePercent = userSharePercent
        self.lastUpdated = lastUpdated
        self.isPendingSync = isPendingSync
    }
    
    var pillar: BudgetPillar {
        BudgetPillar(rawValue: pillarRawValue) ?? .fundamentals
    }
    
    var splitMode: ExpenseSplitMode {
        ExpenseSplitMode(rawValue: splitModeRawValue) ?? .personal
    }
}

@Model
final class LocalExpenseCategory {
    @Attribute(.unique)
    var id: String
    var name: String
    var pillarRawValue: String?
    var isArchived: Bool
    var lastUpdated: Date
    var isPendingSync: Bool
    
    init(
        id: String = UUID().uuidString,
        name: String,
        pillar: BudgetPillar? = nil,
        isArchived: Bool = false,
        lastUpdated: Date = .now,
        isPendingSync: Bool = false
    ) {
        self.id = id
        self.name = name
        self.pillarRawValue = pillar?.rawValue
        self.isArchived = isArchived
        self.lastUpdated = lastUpdated
        self.isPendingSync = isPendingSync
    }
    
    var pillar: BudgetPillar? {
        if let raw = pillarRawValue {
            return BudgetPillar(rawValue: raw)
        }
        return nil
    }
}

@Model
final class LocalRecurringTemplate {
    @Attribute(.unique)
    var id: String
    var title: String
    var amount: Double
    var pillarRawValue: String
    var frequencyRawValue: String
    var categoryId: String?
    var splitModeRawValue: String
    var userSharePercent: Double
    var lastUpdated: Date
    var isPendingSync: Bool
    
    init(
        id: String = UUID().uuidString,
        title: String,
        amount: Double,
        pillar: BudgetPillar,
        frequency: RecurringFrequency,
        categoryId: String? = nil,
        splitMode: ExpenseSplitMode = .personal,
        userSharePercent: Double = 100,
        lastUpdated: Date = .now,
        isPendingSync: Bool = false
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.pillarRawValue = pillar.rawValue
        self.frequencyRawValue = frequency.rawValue
        self.categoryId = categoryId
        self.splitModeRawValue = splitMode.rawValue
        self.userSharePercent = userSharePercent
        self.lastUpdated = lastUpdated
        self.isPendingSync = isPendingSync
    }
    
    var pillar: BudgetPillar {
        BudgetPillar(rawValue: pillarRawValue) ?? .fundamentals
    }
    
    var frequency: RecurringFrequency {
        RecurringFrequency(rawValue: frequencyRawValue) ?? .monthly
    }
    
    var splitMode: ExpenseSplitMode {
        ExpenseSplitMode(rawValue: splitModeRawValue) ?? .personal
    }
}

enum SyncOperationType: String, Codable {
    case create
    case update
    case delete
}

enum SyncEntityType: String, Codable {
    case expense
    case snapshot
    case planItem
    case category
    case recurringTemplate
}

@Model
final class OfflineSyncAction {
    var id: UUID
    var entityId: String
    var entityTypeRawValue: String
    var operationTypeRawValue: String
    var payloadJSON: Data?
    var timestamp: Date
    
    init(
        id: UUID = UUID(),
        entityId: String,
        entityType: SyncEntityType,
        operationType: SyncOperationType,
        payloadJSON: Data? = nil,
        timestamp: Date = .now
    ) {
        self.id = id
        self.entityId = entityId
        self.entityTypeRawValue = entityType.rawValue
        self.operationTypeRawValue = operationType.rawValue
        self.payloadJSON = payloadJSON
        self.timestamp = timestamp
    }
    
    var entityType: SyncEntityType {
        SyncEntityType(rawValue: entityTypeRawValue) ?? .expense
    }
    
    var operationType: SyncOperationType {
        SyncOperationType(rawValue: operationTypeRawValue) ?? .create
    }
}
