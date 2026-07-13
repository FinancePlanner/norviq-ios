import StockPlanShared

enum FinancingServiceUnavailable: Error { case unavailable }

extension ExpensesServicing {
  func simulateFinancing(payload _: FinancingSimulationRequest) async throws -> FinancingSimulationResponse { throw FinancingServiceUnavailable.unavailable }
  func getFinancingPlans() async throws -> [FinancingPlanResponse] { throw FinancingServiceUnavailable.unavailable }
  func createFinancingPlan(payload _: FinancingPlanRequest) async throws -> FinancingPlanResponse { throw FinancingServiceUnavailable.unavailable }
  func getFinancingProjections(from _: String?, to _: String?) async throws -> [FinancingProjectionResponse] { throw FinancingServiceUnavailable.unavailable }
}
