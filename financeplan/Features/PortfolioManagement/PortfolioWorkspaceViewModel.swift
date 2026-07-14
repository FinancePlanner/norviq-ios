import Factory
import Foundation
import Observation
import StockPlanShared

@MainActor @Observable
final class PortfolioWorkspaceViewModel {
  private(set) var portfolios: [Portfolio] = []
  private(set) var members: [PortfolioMembership] = []
  private(set) var invitations: [PortfolioInvitation] = []
  private(set) var cashPositions: [PortfolioCashPosition] = []
  private(set) var comparison: PortfolioComparison?
  private(set) var isLoading = false
  private(set) var isSaving = false
  var errorMessage: String?

  let service: any PortfolioReportingServicing

  init(service: any PortfolioReportingServicing = Container.shared.portfolioReportingService()) {
    self.service = service
  }

  func load() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      portfolios = try await service.portfolios()
      errorMessage = nil
    } catch is CancellationError {
      return
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func loadDetails(for portfolio: Portfolio) async {
    do {
      async let members = service.members(portfolioId: portfolio.id)
      async let invitations = service.invitations(portfolioId: portfolio.id)
      async let cash = service.cash(portfolioId: portfolio.id)
      (self.members, self.invitations, self.cashPositions) = try await (members, invitations, cash)
      errorMessage = nil
    } catch is CancellationError {
      return
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func create(_ request: PortfolioCreateRequest) async -> Bool {
    await save {
      let portfolio = try await service.createPortfolio(request)
      portfolios.append(portfolio)
    }
  }

  func clone(_ portfolio: Portfolio, name: String) async -> Bool {
    await save {
      let clone = try await service.clonePortfolio(
        id: portfolio.id,
        request: PortfolioCloneRequest(name: name)
      )
      portfolios.append(clone)
    }
  }

  func archive(_ portfolio: Portfolio) async -> Bool {
    await save {
      _ = try await service.archivePortfolio(id: portfolio.id)
      portfolios.removeAll { $0.id == portfolio.id }
    }
  }

  func invite(email: String, to portfolio: Portfolio) async -> Bool {
    await save {
      let invitation = try await service.invite(
        portfolioId: portfolio.id,
        request: PortfolioInvitationCreateRequest(email: email)
      )
      invitations.append(invitation)
    }
  }

  func addCash(
    label: String,
    balance: Double,
    currency: String,
    to portfolio: Portfolio
  ) async -> Bool {
    await save {
      let position = try await service.addCash(
        portfolioId: portfolio.id,
        request: PortfolioCashPositionRequest(
          label: label,
          currency: currency,
          balance: balance,
          asOf: ISO8601DateFormatter().string(from: Date())
        )
      )
      cashPositions.append(position)
    }
  }

  func compare(left: Portfolio, right: Portfolio) async {
    do {
      comparison = try await service.comparePortfolios(leftId: left.id, rightId: right.id)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func save(_ operation: () async throws -> Void) async -> Bool {
    guard !isSaving else { return false }
    isSaving = true
    defer { isSaving = false }
    do {
      try await operation()
      errorMessage = nil
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }
}
