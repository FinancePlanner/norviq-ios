import Foundation
import SwiftData

@MainActor
let sharedModelContainer: ModelContainer = {
    let schema = Schema([
        SDPortfolioStock.self,
        SDWatchlistItem.self,
        LocalExpense.self,
        LocalBudgetSnapshot.self,
        LocalBudgetPlanItem.self,
        LocalExpenseCategory.self,
        LocalRecurringTemplate.self,
        OfflineSyncAction.self
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    do {
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()
