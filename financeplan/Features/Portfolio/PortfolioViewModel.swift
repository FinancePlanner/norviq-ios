import Combine
import Factory
import Foundation
import OSLog
import StockPlanShared
import SwiftData

private let portfolioViewModelLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
  category: "PortfolioViewModel"
)

struct PortfolioAllocationSlice: Identifiable, Equatable, Sendable {
  let id: String
  let symbol: String
  let value: Double
  /// Percent of total portfolio value (0–100).
  let percentage: Double
}

@MainActor
final class PortfolioViewModel: ObservableObject {
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var editingStock: StockResponse?
  @Published var isSaving = false
  @Published var isDeletingStock = false

  private let service: StockServicing
  private var modelContext: ModelContext?
  private var hasLoadedOnce = false

  init(service: StockServicing, modelContext: ModelContext? = nil) {
    self.service = service
    self.modelContext = modelContext
  }

  convenience init() {
    self.init(service: Container.shared.stockService())
  }

  func setModelContext(_ context: ModelContext) {
    self.modelContext = context
  }

  func load(force: Bool = false) async {
    if !force, hasLoadedOnce { return }
    guard !isLoading else { return }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let remoteStocks = try await service.fetchPortfolio()
      await syncWithSwiftData(remoteStocks)
      hasLoadedOnce = true
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load portfolio."
    }
  }

  private func syncWithSwiftData(_ remoteStocks: [StockResponse]) async {
    guard let modelContext = modelContext else { return }

    // Simple sync: delete all and re-insert or update existing
    // For now, let's do a simple update/insert and delete others
    let remoteIds = Set(remoteStocks.map { $0.id })
    
    do {
        let descriptor = FetchDescriptor<SDPortfolioStock>()
        let localStocks = try modelContext.fetch(descriptor)
        let localById = Dictionary(uniqueKeysWithValues: localStocks.map { ($0.id, $0) })
        
        // Delete local stocks that are not in remote
        for local in localStocks {
            if !remoteIds.contains(local.id) {
                modelContext.delete(local)
            }
        }
        
        // Update or insert remote stocks
        for remote in remoteStocks {
            if let existing = localById[remote.id] {
                existing.update(from: remote)
            } else {
                modelContext.insert(SDPortfolioStock(from: remote))
            }
        }
        
        try modelContext.save()
    } catch {
        portfolioViewModelLogger.error("SwiftData portfolio sync failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  @discardableResult
  func delete(id: String) async -> Bool {
    guard !isDeletingStock else { return false }
    isDeletingStock = true
    errorMessage = nil
    defer { isDeletingStock = false }

    do {
      try await service.delete(id: id)
      
      if let modelContext = modelContext {
          let descriptor = FetchDescriptor<SDPortfolioStock>(predicate: #Predicate { $0.id == id })
          if let local = try modelContext.fetch(descriptor).first {
              modelContext.delete(local)
              try modelContext.save()
          }
      }

      if editingStock?.id == id {
        editingStock = nil
      }
      return true
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to delete stock."
      return false
    }
  }

  func beginEdit(_ stock: StockResponse) {
    editingStock = stock
  }

  func saveEdit(_ updated: StockResponse) async -> Bool {
    guard !isSaving else { return false }
    isSaving = true
    defer { isSaving = false }

    do {
      let saved = try await service.updateStock(updated)

      if let modelContext = modelContext {
          let id = saved.id
          let descriptor = FetchDescriptor<SDPortfolioStock>(predicate: #Predicate { $0.id == id })
          if let local = try modelContext.fetch(descriptor).first {
              local.update(from: saved)
          } else {
              modelContext.insert(SDPortfolioStock(from: saved))
          }
          try modelContext.save()
      }

      editingStock = nil
      return true
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to update stock."
      return false
    }
  }

  func saveNewPosition(_ draft: AddPositionDraft) async -> String? {
    guard !isSaving else { return "Already saving." }

    let symbol = draft.symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard !symbol.isEmpty,
      let shares = Double(draft.shares),
      let buyPrice = Double(draft.buyPrice)
    else {
      return "Enter valid symbol, shares, and buy price."
    }

    isSaving = true
    defer { isSaving = false }

    do {
      let saved = try await service.create(
        stock: StockRequest(
          symbol: symbol,
          shares: shares,
          buyPrice: buyPrice,
          buyDate: DateFormatter.yyyyMMdd.string(from: draft.buyDate),
          notes: draft.notes.isEmpty ? nil : draft.notes,
          category: draft.category
        )
      )

      if let modelContext = modelContext {
          modelContext.insert(SDPortfolioStock(from: saved))
          try modelContext.save()
      }

      return nil
    } catch {
      let message = (error as? LocalizedError)?.errorDescription ?? "Failed to create stock."
      errorMessage = message
      return message
    }
  }
}
