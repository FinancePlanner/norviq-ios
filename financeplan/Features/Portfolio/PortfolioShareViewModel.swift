import Factory
import Foundation
import Observation
import StockPlanShared

/// Splits a user's live links into the one for the scope on screen and the
/// rest, so a link made elsewhere (e.g. "all" on the web) can still be revoked.
nonisolated enum PortfolioShareLinks {
  static func split(
    _ links: [PortfolioShareLinkResponse],
    scope: String
  ) -> (current: PortfolioShareLinkResponse?, others: [PortfolioShareLinkResponse]) {
    (links.first { $0.scope == scope }, links.filter { $0.scope != scope })
  }
}

/// Owns the public share links for one portfolio scope ("all" or a portfolio id).
@MainActor
@Observable
final class PortfolioShareViewModel {
  private(set) var link: PortfolioShareLinkResponse?
  /// Live links from other scopes; shown so "stop sharing" is never partial.
  private(set) var others: [PortfolioShareLinkResponse] = []
  private(set) var isBusy = false
  var errorMessage: String?

  private let service: any StockServicing

  init(service: any StockServicing = Container.shared.stockService()) {
    self.service = service
  }

  func load(scope: String) async {
    guard let links = try? await service.fetchShareLinks() else { return }
    (link, others) = PortfolioShareLinks.split(links, scope: scope)
  }

  func create(scope: String) async {
    await run { self.link = try await self.service.createShareLink(scope: scope) }
  }

  /// Revokes `target` (default: the on-screen scope), then reloads everything.
  func revoke(scope: String, target: String? = nil) async {
    await run {
      try await self.service.revokeShareLink(scope: target ?? scope)
    }
    await load(scope: scope)
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
