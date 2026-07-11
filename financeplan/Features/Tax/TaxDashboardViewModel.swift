import Foundation
import Observation
import StockPlanShared

@MainActor @Observable
final class TaxDashboardViewModel {
  var dashboard: TaxDashboardResponse?
  var scenario: TaxScenarioResponse?
  var actionPlan: TaxActionPlanResponse?
  var isLoading = false
  var errorMessage: String?
  var selectedJurisdiction: TaxJurisdiction = .unitedStates
  private let service: TaxServiceProtocol

  init(service: TaxServiceProtocol) { self.service = service }

  func load() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      dashboard = try await service.dashboard(
        jurisdiction: selectedJurisdiction,
        taxYear: Calendar.current.component(.year, from: Date())
      )
    } catch {
      errorMessage = "We couldn't refresh your tax estimate. Try again shortly."
    }
  }

  func simulate(_ opportunity: TaxOpportunityResponse) async {
    do {
      scenario = try await service.createScenario(.init(
        taxYear: Calendar.current.component(.year, from: Date()),
        opportunityIds: [opportunity.id]
      ))
    } catch { errorMessage = "The scenario could not be created." }
  }

  func applyScenario() async {
    guard let scenario else { return }
    do {
      actionPlan = try await service.createActionPlan(.init(
        scenarioId: scenario.id,
        idempotencyKey: UUID().uuidString
      ))
    } catch { errorMessage = "The action plan could not be created." }
  }
}
