import Foundation
import StockPlanShared
import Factory

protocol GoalsServicing: Sendable {
    func getGoals() async throws -> [GoalResponse]
    func createGoal(payload: GoalRequest) async throws -> GoalResponse
    func updateGoal(id: String, payload: GoalRequest) async throws -> GoalResponse
    func updateGoalStatus(id: String, payload: GoalStatusUpdateRequest) async throws -> GoalResponse
    func deleteGoal(id: String) async throws
}

struct DefaultGoalsService: GoalsServicing, @unchecked Sendable {
    let client: GoalsHTTPClient

    init(environmentManager: AppEnvironmentManager, authSessionManager: any AuthSessionManaging) {
        let env = environmentManager.current
        self.client = GoalsHTTPClient(
            baseURL: env.apiBaseUrl,
            session: URLSession.shared,
            authTokenProvider: { await Container.shared.authSessionStore().authToken }
        )
    }

    func getGoals() async throws -> [GoalResponse] {
        try await client.getGoals()
    }

    func createGoal(payload: GoalRequest) async throws -> GoalResponse {
        try await client.createGoal(payload)
    }

    func updateGoal(id: String, payload: GoalRequest) async throws -> GoalResponse {
        try await client.updateGoal(id: id, payload: payload)
    }

    func updateGoalStatus(id: String, payload: GoalStatusUpdateRequest) async throws -> GoalResponse {
        try await client.updateGoalStatus(id: id, payload: payload)
    }

    func deleteGoal(id: String) async throws {
        try await client.deleteGoal(id: id)
    }
}


