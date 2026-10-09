import Foundation
import Observation
import StockPlanShared
import SwiftUI

enum TerminalPreferences {
  /// Display-only "round down to whole shares", shared by the screen, editor and cards.
  static let roundDownKey = "terminalPositions.roundDownShares"
  static let sampleDismissedKey = "terminalPositions.sampleDismissed"
}

/// What a terminal-positions surface shows for a failed request.
enum TerminalPositionsErrorText {
  static func isCancellation(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    if case .cancelled? = error as? TerminalPositionsHTTPClient.Error { return true }
    return false
  }

  /// Nil means show nothing (the screen went away mid-request). A 422 shows the
  /// server's reason, which is written for people ("Ticker is invalid").
  static func message(for error: Error, fallback: String, notFound: String? = nil) -> String? {
    if isCancellation(error) { return nil }
    switch error as? TerminalPositionsHTTPClient.Error {
    case .rejected(status: 422, message: let message?)? where !message.isEmpty:
      return message
    case .rejected(status: 404, message: _)? where notFound != nil:
      return notFound
    default:
      return fallback
    }
  }
}

@MainActor @Observable
final class TerminalPositionsViewModel {
  /// Footer totals over valid rows. "Total shares-needed notional at terminal
  /// prices" is left out on purpose: it always equals total value wanted.
  struct Totals: Equatable {
    let valueWanted: Double
    let gapValueAtTerminal: Double
    /// Nil when no valid row has today's price.
    let capitalAtTodayPrice: Double?
  }

  /// The empty-state example: a 10T cap on 11B shares is 909.09 a share, so
  /// 1M takes 1,100 shares. It is only stored when the user taps "Use AMZN sample".
  static let sampleRequest = TerminalPositionCreateRequest(
    ticker: "AMZN",
    sharesOutstanding: nil,
    terminalShareCount: 11_000_000_000,
    terminalMarketCap: 10_000_000_000_000,
    valueWanted: 1_000_000,
    sharesOwned: nil,
    currentSharePrice: nil,
    notes: nil
  )

  static var samplePreview: TerminalScenarioResult? {
    let input = TerminalScenarioInput(
      terminalShareCount: sampleRequest.terminalShareCount,
      terminalMarketCap: sampleRequest.terminalMarketCap,
      valueWanted: sampleRequest.valueWanted
    )
    if case let .success(result) = TerminalMath.evaluate(input) { return result }
    return nil
  }

  private(set) var positions: [TerminalPositionResponse] = []
  private(set) var autobuys: [AutobuyResponse] = []
  private(set) var currency = "USD"
  private(set) var monthlyAutobuyTotal: Double = 0
  private(set) var hasLoaded = false
  private(set) var isSampleDismissed: Bool
  var isLoading = false
  var errorMessage: String?

  private let service: any TerminalPositionsServicing
  private let defaults: UserDefaults
  private var reorderTask: Task<Void, Never>?
  private var reorderGeneration = 0

  init(service: any TerminalPositionsServicing, defaults: UserDefaults = .standard) {
    self.service = service
    self.defaults = defaults
    isSampleDismissed = defaults.bool(forKey: TerminalPreferences.sampleDismissedKey)
  }

  var showsSample: Bool { hasLoaded && positions.isEmpty && !isSampleDismissed }

  var totals: Totals {
    let valid = positions.filter { $0.scenarioError == nil }
    let priced = valid.compactMap(\.capitalAtTodayPrice)
    return Totals(
      valueWanted: valid.reduce(0) { $0 + $1.valueWanted },
      gapValueAtTerminal: valid.reduce(0) { $0 + ($1.gapValueAtTerminal ?? 0) },
      capitalAtTodayPrice: priced.isEmpty ? nil : priced.reduce(0, +)
    )
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    async let listRequest = service.list(ticker: nil)
    async let autobuysRequest = service.autobuys()
    var listFailed = false
    do {
      let list = try await listRequest
      positions = list.positions
      currency = list.currency
      hasLoaded = true
    } catch {
      listFailed = true
      show(error, fallback: String(localized: "Terminal positions are unavailable right now."))
    }
    do {
      apply(try await autobuysRequest)
    } catch {
      // When the backend is down both requests fail; the positions message wins.
      if !listFailed {
        show(error, fallback: String(localized: "Autobuys are unavailable right now."))
      }
    }
  }

  func reloadAutobuys() async {
    do {
      apply(try await service.autobuys())
    } catch {
      show(error, fallback: String(localized: "Autobuys are unavailable right now."))
    }
  }

  func useSample() async {
    do {
      positions.append(try await service.create(Self.sampleRequest))
    } catch {
      show(error, fallback: String(localized: "The sample could not be added."))
    }
  }

  func dismissSample() {
    defaults.set(true, forKey: TerminalPreferences.sampleDismissedKey)
    isSampleDismissed = true
  }

  /// The editor's result: replaces the row it edited, or appends a new one.
  func saved(_ position: TerminalPositionResponse) {
    if let index = positions.firstIndex(where: { $0.id == position.id }) {
      positions[index] = position
    } else {
      positions.append(position)
    }
  }

  func delete(_ position: TerminalPositionResponse) async {
    guard let index = positions.firstIndex(where: { $0.id == position.id }) else { return }
    positions.remove(at: index)
    do {
      try await service.delete(id: position.id)
    } catch {
      // Already deleted on another device: the row is gone either way.
      if case .rejected(status: 404, message: _)? = error as? TerminalPositionsHTTPClient.Error { return }
      positions.insert(position, at: min(index, positions.count))
      show(error, fallback: String(localized: "The row could not be deleted."))
    }
  }

  func duplicate(_ position: TerminalPositionResponse) async {
    do {
      let copy = try await service.duplicate(id: position.id)
      let index = positions.firstIndex(where: { $0.id == position.id }).map { $0 + 1 } ?? positions.count
      positions.insert(copy, at: index)
    } catch {
      show(
        error,
        fallback: String(localized: "The row could not be duplicated."),
        notFound: String(localized: "That row no longer exists. Pull to refresh.")
      )
    }
  }

  /// Moves the rows at once (SwiftUI expects `onMove` to change the data
  /// synchronously), then saves the full order. Saves run one after another.
  /// Only the newest one applies the server's answer, and if the newest fails,
  /// the list reloads, so it never shows an order the server doesn't have.
  @discardableResult
  func move(fromOffsets source: IndexSet, toOffset destination: Int) -> Task<Void, Never>? {
    let before = positions.map(\.id)
    positions.move(fromOffsets: source, toOffset: destination)
    let ids = positions.map(\.id)
    guard ids != before else {
      return nil
    }
    reorderGeneration += 1
    let generation = reorderGeneration
    let previous = reorderTask
    let task = Task {
      await previous?.value
      await commitOrder(ids, generation: generation)
    }
    reorderTask = task
    return task
  }

  private func commitOrder(_ ids: [String], generation: Int) async {
    do {
      let list = try await service.reorder(ids: ids)
      guard generation == reorderGeneration else {
        return
      }
      positions = list.positions
    } catch {
      guard generation == reorderGeneration, !TerminalPositionsErrorText.isCancellation(error) else {
        return
      }
      errorMessage = String(localized: "The new order could not be saved.")
      await load()
    }
  }

  private func apply(_ list: AutobuysListResponse) {
    autobuys = list.autobuys
    monthlyAutobuyTotal = list.monthlyTotal
  }

  private func show(_ error: Error, fallback: String, notFound: String? = nil) {
    if let message = TerminalPositionsErrorText.message(for: error, fallback: fallback, notFound: notFound) {
      errorMessage = message
    }
  }
}
