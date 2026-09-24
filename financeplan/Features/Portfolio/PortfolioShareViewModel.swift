import Factory
import Foundation
import Observation
import StockPlanShared

/// Owns the public share link for one portfolio scope ("all" or a portfolio id).
@MainActor
@Observable
final class PortfolioShareViewModel {
  private(set) var link: PortfolioShareLinkResponse?
  private(set) var isBusy = false
  var errorMessage: String?

  private let service: any StockServicing

  init(service: any StockServicing = Container.shared.stockService()) {
    self.service = service
  }

  func load(scope: String) async {
    link = try? await service.fetchShareLink(scope: scope)
  }

  func create(scope: String) async {
    await run { self.link = try await self.service.createShareLink(scope: scope) }
  }

  func revoke(scope: String) async {
    await run {
      try await self.service.revokeShareLink(scope: scope)
      self.link = nil
    }
  }

  private func run(_ work: () async throws -> Void) async {
    isBusy = true
    defer { isBusy = false }
    do {
      try await work()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
