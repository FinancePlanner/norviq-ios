import Foundation
import StockPlanShared
import Factory

protocol GoalsServicing {
    func getGoals() async throws -> [GoalResponse]
    func createGoal(payload: GoalRequest) async throws -> GoalResponse
    func updateGoal(id: String, payload: GoalRequest) async throws -> GoalResponse
    func updateGoalStatus(id: String, payload: GoalStatusUpdateRequest) async throws -> GoalResponse
    func deleteGoal(id: String) async throws
}

struct DefaultGoalsService: GoalsServicing {
    let client: GoalsHTTPClient

    init(environmentManager: AppEnvironmentManager, authSessionManager: any AuthSessionManaging) {
        let env = environmentManager.current
        self.client = GoalsHTTPClient(
            baseURL: env.apiBaseUrl,
            session: .shared,
            authTokenProvider: { Container.shared.authSessionStore().authToken }
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

struct GoalsServiceStub: GoalsServicing {
    func getGoals() async throws -> [GoalResponse] {
        [
            GoalResponse(id: UUID().uuidString, title: "Max out 401k", status: .pending),
            GoalResponse(id: UUID().uuidString, title: "Save for European vacation", status: .completed)
        ]
    }
    
    func createGoal(payload: GoalRequest) async throws -> GoalResponse {
        GoalResponse(id: UUID().uuidString, title: payload.title, status: .pending)
    }
    
    func updateGoal(id: String, payload: GoalRequest) async throws -> GoalResponse {
        GoalResponse(id: id, title: payload.title, status: .pending)
    }

    func updateGoalStatus(id: String, payload: GoalStatusUpdateRequest) async throws -> GoalResponse {
        GoalResponse(
            id: id,
            title: "Updated",
            status: payload.status,
            statusUpdatedBy: payload.source,
            completedAt: payload.status == .completed ? ISO8601DateFormatter().string(from: Date()) : nil
        )
    }
    
    func deleteGoal(id: String) async throws {}
}
