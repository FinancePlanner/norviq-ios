import Foundation
import SwiftData
import StockPlanShared
import Factory
import OSLog

@MainActor
final class ExpensesSyncManager {
    static let shared = ExpensesSyncManager()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "ExpensesSyncManager")
    private var isSyncing = false
    
    var context: ModelContext {
        sharedModelContainer.mainContext
    }
    
    func pullLatestData(from service: any ExpensesServicing) async throws {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        
        logger.debug("Starting pullLatestData from API")
        
        async let fetchSnapshots = service.getSnapshots(year: nil, month: nil)
        async let fetchItems = service.getAllPlanItems()
        async let fetchExpenses = service.getExpenses(from: nil, to: nil)
        async let fetchCategories = service.getCategories()
        async let fetchRecurringTemplates = service.getRecurringTemplates()
        
        let (fetchedSnapshots, fetchedItems, fetchedExpenses, fetchedCategories, fetchedRecurringTemplates) = try await (
            fetchSnapshots, fetchItems, fetchExpenses, fetchCategories, fetchRecurringTemplates
        )
        
        // Update Categories
        let existingCategories = try context.fetch(FetchDescriptor<LocalExpenseCategory>())
        let existingCategoryMap = Dictionary(uniqueKeysWithValues: existingCategories.map { ($0.id, $0) })
        for cat in fetchedCategories {
            if let existing = existingCategoryMap[cat.id] {
                existing.name = cat.name
                existing.pillarRawValue = cat.pillar?.rawValue
            } else {
                let newCat = LocalExpenseCategory(
                    id: cat.id,
                    name: cat.name,
                    pillar: cat.pillar
                )
                context.insert(newCat)
            }
        }
        
        // Update Recurring Templates
        let existingTemplates = try context.fetch(FetchDescriptor<LocalRecurringTemplate>())
        let existingTemplateMap = Dictionary(uniqueKeysWithValues: existingTemplates.map { ($0.id, $0) })
        for tpl in fetchedRecurringTemplates {
            if let existing = existingTemplateMap[tpl.id] {
                existing.title = tpl.title
                existing.amount = tpl.amount
                existing.pillarRawValue = tpl.pillar.rawValue
                existing.frequencyRawValue = tpl.frequency.rawValue
                existing.categoryId = tpl.categoryId
                existing.splitModeRawValue = tpl.splitMode.rawValue
                existing.userSharePercent = tpl.userSharePercent
            } else {
                let newTpl = LocalRecurringTemplate(
                    id: tpl.id,
                    title: tpl.title,
                    amount: tpl.amount,
                    pillar: tpl.pillar,
                    frequency: tpl.frequency,
                    categoryId: tpl.categoryId,
                    splitMode: tpl.splitMode,
                    userSharePercent: tpl.userSharePercent
                )
                context.insert(newTpl)
            }
        }
        
        // Parse dates safely
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        let parseDate: (String) -> Date? = { dateString in
            let segments = dateString.split(separator: "-")
            guard segments.count == 3,
                  let year = Int(segments[0]),
                  let month = Int(segments[1]),
                  let day = Int(segments[2]) else { return nil }
            return Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
        }
        
        // Update Snapshots
        let existingSnapshots = try context.fetch(FetchDescriptor<LocalBudgetSnapshot>())
        let existingSnapshotMap = Dictionary(uniqueKeysWithValues: existingSnapshots.map { ($0.id.uuidString, $0) })
        var currentSnapshots: [LocalBudgetSnapshot] = []
        for snap in fetchedSnapshots {
            guard let monthStart = parseDate(snap.monthStart) else { continue }
            var targetSharesRaw: [String: Double] = [:]
            for (k, v) in snap.targetShares { targetSharesRaw[k] = v }
            
            if let existing = existingSnapshotMap[snap.id] {
                existing.monthStart = monthStart
                existing.netSalary = snap.netSalary
                existing.targetSharesRaw = targetSharesRaw
                currentSnapshots.append(existing)
            } else if let id = UUID(uuidString: snap.id) {
                var shares: [BudgetPillar: Double] = [:]
                for (k, v) in snap.targetShares {
                    if let p = BudgetPillar(rawValue: k) { shares[p] = v }
                }
                let newSnap = LocalBudgetSnapshot(
                    id: id,
                    monthStart: monthStart,
                    netSalary: snap.netSalary,
                    targetShares: shares
                )
                context.insert(newSnap)
                currentSnapshots.append(newSnap)
            }
        }
        let currentSnapshotMap = Dictionary(uniqueKeysWithValues: currentSnapshots.map { ($0.id.uuidString, $0) })
        
        // Update Plan Items
        let existingItems = try context.fetch(FetchDescriptor<LocalBudgetPlanItem>())
        let existingItemMap = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.id.uuidString, $0) })
        for item in fetchedItems {
            if let existing = existingItemMap[item.id] {
                existing.title = item.title
                existing.plannedAmount = item.plannedAmount
                existing.pillarRawValue = item.pillar.rawValue
                existing.categoryId = item.categoryId
                existing.splitModeRawValue = item.splitMode.rawValue
                existing.userSharePercent = item.userSharePercent
                if existing.snapshot?.id.uuidString != item.snapshotId {
                    existing.snapshot = currentSnapshotMap[item.snapshotId]
                }
            } else if let id = UUID(uuidString: item.id) {
                let newItem = LocalBudgetPlanItem(
                    id: id,
                    title: item.title,
                    plannedAmount: item.plannedAmount,
                    pillar: item.pillar,
                    categoryId: item.categoryId,
                    splitMode: item.splitMode,
                    userSharePercent: item.userSharePercent
                )
                newItem.snapshot = currentSnapshotMap[item.snapshotId]
                context.insert(newItem)
            }
        }
        
        // Update Expenses
        let existingExpenses = try context.fetch(FetchDescriptor<LocalExpense>())
        let existingExpenseMap = Dictionary(uniqueKeysWithValues: existingExpenses.map { ($0.id.uuidString, $0) })
        for exp in fetchedExpenses {
            guard let occurredOn = parseDate(exp.occurredOn) else { continue }
            if let existing = existingExpenseMap[exp.id] {
                existing.title = exp.title
                existing.amount = exp.amount
                existing.pillarRawValue = exp.pillar.rawValue
                existing.occurredOn = occurredOn
                existing.linkedPlanItemId = exp.linkedPlanItemId.flatMap { UUID(uuidString: $0) }
                existing.categoryId = exp.categoryId
                existing.splitModeRawValue = exp.splitMode.rawValue
                existing.userSharePercent = exp.userSharePercent
                existing.foreignAmount = exp.foreignAmount
                existing.foreignCurrency = exp.foreignCurrency
                existing.exchangeRate = exp.exchangeRate
            } else if let id = UUID(uuidString: exp.id) {
                let newExp = LocalExpense(
                    id: id,
                    title: exp.title,
                    amount: exp.amount,
                    pillar: exp.pillar,
                    occurredOn: occurredOn,
                    linkedPlanItemId: exp.linkedPlanItemId.flatMap { UUID(uuidString: $0) },
                    categoryId: exp.categoryId,
                    splitMode: exp.splitMode,
                    userSharePercent: exp.userSharePercent,
                    foreignAmount: exp.foreignAmount,
                    foreignCurrency: exp.foreignCurrency,
                    exchangeRate: exp.exchangeRate
                )
                context.insert(newExp)
            }
        }
        
        try context.save()
        logger.debug("Successfully pulled latest data into SwiftData")
    }
    
    func pushPendingActions(to service: any ExpensesServicing) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let pendingActions = try context.fetch(FetchDescriptor<OfflineSyncAction>(sortBy: [SortDescriptor(\.timestamp, order: .forward)]))
            for action in pendingActions {
                do {
                    switch action.operationType {
                    case .create:
                        if action.entityType == .expense {
                            if let payload = action.payloadJSON, let request = try? JSONDecoder().decode(ExpenseRequest.self, from: payload) {
                                _ = try await service.createExpense(request: request)
                            }
                        }
                        // Handle other creates if needed
                    case .update:
                        if action.entityType == .expense {
                            if let payload = action.payloadJSON, let request = try? JSONDecoder().decode(ExpenseRequest.self, from: payload) {
                                _ = try await service.updateExpense(expenseId: action.entityId, payload: request)
                            }
                        }
                    case .delete:
                        if action.entityType == .expense {
                            try await service.deleteExpense(expenseId: action.entityId)
                        }
                    }
                    context.delete(action)
                } catch {
                    logger.error("Failed to push action \(action.id.uuidString, privacy: .public): \(error)")
                }
            }
            try context.save()
        } catch {
            logger.error("Failed to fetch or save pending actions: \(error)")
        }
    }
}
