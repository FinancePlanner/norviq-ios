import Foundation
import Observation
import StockPlanShared

@MainActor @Observable
final class TaxDashboardViewModel {
  var dashboard: TaxDashboardResponse?
  var profileContext: TaxProfileContextResponse?
  var scenario: TaxScenarioResponse?
  var actionPlan: TaxActionPlanResponse?
  var locationScenario: TaxLocationScenarioResponse?
  var actionPlans: [TaxActionPlanResponse] = []
  var isLoading = false
  var errorMessage: String?
  var selectedJurisdiction: TaxJurisdiction = .unitedStates
  private let service: TaxServiceProtocol

  init(service: TaxServiceProtocol) {
    self.service = service
  }

  func load() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      async let context = service.profileContext(
        jurisdiction: selectedJurisdiction,
        taxYear: Calendar.current.component(.year, from: Date())
      )
      dashboard = try await service.dashboard(
        jurisdiction: selectedJurisdiction,
        taxYear: Calendar.current.component(.year, from: Date())
      )
      profileContext = try await context
      actionPlans = await (try? service.actionPlans()) ?? []
    } catch {
      errorMessage = "We couldn't refresh your tax estimate. Try again shortly."
    }
  }

  func reloadProfileContext() async {
    do {
      profileContext = try await service.profileContext(
        jurisdiction: selectedJurisdiction,
        taxYear: Calendar.current.component(.year, from: Date())
      )
    } catch { errorMessage = "Market classifications could not be refreshed." }
  }

  func simulate(_ opportunity: TaxOpportunityResponse, replacement: TaxReplacementCandidate?) async {
    do {
      let taxYear = Calendar.current.component(.year, from: Date())
      scenario = try await service.createScenario(
        .init(
          taxYear: taxYear,
          opportunityIds: [opportunity.id],
          plannedReplacementInstrumentIds: replacement.map { [opportunity.id: $0.instrumentId] } ?? [:]
        ),
        jurisdiction: selectedJurisdiction,
        taxYear: taxYear
      )
    } catch { errorMessage = "The scenario could not be created." }
  }

  func dismiss(_ opportunity: TaxOpportunityResponse) async {
    do {
      try await service.dismissOpportunity(
        id: opportunity.id,
        jurisdiction: selectedJurisdiction,
        taxYear: Calendar.current.component(.year, from: Date())
      )
      await load()
    } catch { errorMessage = "The opportunity could not be dismissed." }
  }

  func restore(_ opportunity: TaxOpportunityResponse) async {
    do {
      try await service.restoreOpportunity(
        id: opportunity.id,
        taxYear: Calendar.current.component(.year, from: Date())
      )
      await load()
    } catch { errorMessage = "The opportunity could not be restored." }
  }

  func simulateLocation(_ opportunity: TaxLocationOpportunity) async {
    do {
      let taxYear = Calendar.current.component(.year, from: Date())
      locationScenario = try await service.createLocationScenario(
        .init(
          taxYear: taxYear,
          opportunityIds: [opportunity.id]
        ),
        jurisdiction: selectedJurisdiction,
        taxYear: taxYear
      )
    } catch { errorMessage = "The asset-location scenario could not be created." }
  }

  func applyLocationScenario() async {
    guard let locationScenario else { return }
    do {
      actionPlan = try await service.createPlacementPlan(.init(
        scenarioId: locationScenario.id,
        idempotencyKey: UUID().uuidString
      ))
      actionPlans = await (try? service.actionPlans()) ?? actionPlans
    } catch { errorMessage = "The placement plan could not be created." }
  }

  func transition(_ plan: TaxActionPlanResponse, to status: TaxActionPlanStatus) async {
    do {
      actionPlan = try await service.transitionActionPlan(
        id: plan.id,
        request: .init(
          status: status,
          executedAt: status == .completed ? ISO8601DateFormatter().string(from: Date()) : nil
        )
      )
      actionPlans = await (try? service.actionPlans()) ?? actionPlans
    } catch { errorMessage = "The action plan could not be updated." }
  }

  func applyScenario() async {
    guard let scenario else { return }
    do {
      actionPlan = try await service.createActionPlan(.init(
        scenarioId: scenario.id,
        idempotencyKey: UUID().uuidString
      ))
      actionPlans = await (try? service.actionPlans()) ?? actionPlans
    } catch { errorMessage = "The action plan could not be created." }
  }
}
