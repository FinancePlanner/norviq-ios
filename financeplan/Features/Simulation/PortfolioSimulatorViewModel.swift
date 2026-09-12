import Factory
import Foundation
import SwiftUI
import StockPlanShared

@Observable
@MainActor
final class PortfolioSimulatorViewModel {
  /// One editable row. Weight is held as a percentage because that is what the
  /// user types; basis points are the wire format and the conversion happens at
  /// the boundary.
  struct Leg: Identifiable, Hashable {
    let id = UUID()
    var symbol: String = ""
    var weightPercent: Double = 0

    var basisPoints: Int {
      Int((weightPercent * 100).rounded())
    }

    var isFilled: Bool {
      !symbol.trimmingCharacters(in: .whitespaces).isEmpty && basisPoints > 0
    }
  }

  private(set) var result: PortfolioSimulationResult?
  private(set) var portfolios: [PortfolioListDTOResponse] = []
  private(set) var isRunning = false
  private(set) var errorMessage: String?

  var name: String = "Untitled simulation"
  var targetCapital: Double = 10000
  var baseCurrency: String = "USD"
  var fractionalSharesEnabled = false
  var sourcePortfolioId: String?
  var legs: [Leg] = [Leg(), Leg(), Leg()]

  @ObservationIgnored private let service: any PortfolioSimulationServicing

  init(service: (any PortfolioSimulationServicing)? = nil) {
    self.service = service ?? Container.shared.portfolioSimulationService()
  }

  // MARK: - Derived state

  var claimedBasisPoints: Int {
    legs.reduce(0) { $0 + max(0, $1.basisPoints) }
  }

  /// The remainder is a real cash position, not a validation failure. Only
  /// over-allocation blocks a run.
  var cashBasisPoints: Int {
    max(0, 10000 - claimedBasisPoints)
  }

  var isOverAllocated: Bool {
    claimedBasisPoints > 10000
  }

  var canSimulate: Bool {
    !isOverAllocated && !isRunning && legs.contains(where: \.isFilled) && targetCapital > 0
  }

  var mode: PortfolioSimulationMode {
    sourcePortfolioId == nil ? .fromScratch : .cloneCurrentPortfolio
  }

  /// Whole-share rounding is why a fully invested target still leaves cash, so
  /// the screen can say so instead of looking wrong.
  var showsRoundingNote: Bool {
    !fractionalSharesEnabled && (result?.leftoverCash ?? 0) > 0
  }

  // MARK: - Actions

  func addLeg() {
    legs.append(Leg())
  }

  func removeLeg(at offsets: IndexSet) {
    legs.remove(atOffsets: offsets)
    if legs.isEmpty {
      legs = [Leg()]
    }
  }

  /// Spreads the whole portfolio evenly across the filled rows.
  func equalWeight() {
    let filled = legs.indices.filter { !legs[$0].symbol.trimmingCharacters(in: .whitespaces).isEmpty }
    guard !filled.isEmpty else { return }
    let share = (100.0 / Double(filled.count) * 100).rounded() / 100
    for index in filled {
      legs[index].weightPercent = share
    }
  }

  func loadPortfolios() async {
    // Not having a portfolio to compare against is an ordinary state, not an
    // error worth showing: the simulator works from scratch.
    portfolios = await (try? service.portfolios()) ?? []
  }

  func simulate() async {
    guard canSimulate else { return }
    isRunning = true
    errorMessage = nil
    defer { isRunning = false }

    do {
      result = try await service.preview(makeRequest())
    } catch {
      result = nil
      errorMessage = Self.message(for: error)
    }
  }

  func save() async -> PortfolioSimulation? {
    guard canSimulate else { return nil }
    isRunning = true
    errorMessage = nil
    defer { isRunning = false }

    do {
      return try await service.create(makeRequest())
    } catch {
      errorMessage = Self.message(for: error)
      return nil
    }
  }

  private func makeRequest() -> PortfolioSimulationUpsertRequest {
    PortfolioSimulationUpsertRequest(
      name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled simulation" : name,
      mode: mode,
      sourcePortfolioId: sourcePortfolioId,
      baseCurrency: baseCurrency,
      targetCapital: targetCapital,
      fractionalSharesEnabled: fractionalSharesEnabled,
      legs: legs.filter(\.isFilled).map {
        PortfolioSimulationLegInput(
          symbol: $0.symbol.trimmingCharacters(in: .whitespaces).uppercased(),
          targetBasisPoints: $0.basisPoints
        )
      }
    )
  }

  private static func message(for error: any Error) -> String {
    // The backend names the offending tickers in its 422s, and those arrive as
    // `.api`, so prefer that text over a generic failure string.
    if
      let clientError = error as? StockHTTPClient.Error,
      let description = clientError.errorDescription,
      !description.isEmpty
    {
      return description
    }
    return error.localizedDescription
  }
}

extension PortfolioSimulatorViewModel {
  /// Basis points rendered as the percentage the UI shows.
  static func percent(_ basisPoints: Int) -> String {
    (Double(basisPoints) / 100).formatted(.number.precision(.fractionLength(0...2))) + "%"
  }

  static func money(_ value: Double, currency: String) -> String {
    value.formatted(.currency(code: currency).precision(.fractionLength(2)))
  }

  static func quantity(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...4)))
  }
}
