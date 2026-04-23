import AnyAPI
import Foundation
import OSLog
import StockPlanShared

private let goalsHTTPLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
    category: "GoalsHTTPClient"
)

struct GoalsHTTPClient {
    let baseURL: URL
    let session: URLSession
    let authTokenProvider: () -> String?

    init(baseURL: URL, session: URLSession = .shared, authTokenProvider: @escaping () -> String? = { nil }) {
        self.baseURL = baseURL
        self.session = session
        self.authTokenProvider = authTokenProvider
    }

    func getGoals() async throws -> [GoalResponse] {
        try await call(GetGoalsEndpoint())
    }

    func createGoal(_ payload: GoalRequest) async throws -> GoalResponse {
        try await call(CreateGoalEndpoint(payload: payload))
    }

    func updateGoal(id: String, payload: GoalRequest) async throws -> GoalResponse {
        try await call(UpdateGoalEndpoint(id: id, payload: payload))
    }

    func updateGoalStatus(id: String, payload: GoalStatusUpdateRequest) async throws -> GoalResponse {
        try await call(UpdateGoalStatusEndpoint(id: id, payload: payload))
    }

    func deleteGoal(id: String) async throws {
        _ = try await call(DeleteGoalEndpoint(id: id))
    }

    private func call<E: Endpoint>(_ endpoint: E) async throws -> E.Response where E.Response: Codable {
        let request = try makeURLRequest(for: endpoint)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DashboardHTTPClient.Error.invalidResponse
        }

        goalsHTTPLogger.debug("Goals response [\(endpoint.path)] status=\(httpResponse.statusCode)")

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = APIErrorDecoding.message(from: data)
            if httpResponse.statusCode == 401 {
                throw DashboardHTTPClient.Error.unauthorized(message)
            }
            if let message, !message.isEmpty { throw DashboardHTTPClient.Error.api(message) }
            throw DashboardHTTPClient.Error.invalidStatus(httpResponse.statusCode)
        }

        do {
            return try endpoint.decode(data)
        } catch {
            if let envelope = try? endpoint.decoder.decode(HTTPEnvelope<E.Response>.self, from: data), let payload = envelope.data {
                return payload
            }
            throw error
        }
    }

    private func makeURLRequest<E: Endpoint>(for endpoint: E) throws -> URLRequest {
        let normalizedPath = endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let base = baseURL.appendingPathComponent(normalizedPath)
        let parameters = try endpoint.asParameters()

        var urlComponents = URLComponents(url: base, resolvingAgainstBaseURL: false)
        if endpoint.method == .get, !parameters.isEmpty {
            urlComponents?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: String(describing: $0.value)) }
        }
        guard let url = urlComponents?.url else { throw DashboardHTTPClient.Error.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authTokenProvider(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if endpoint.method != .get, !parameters.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        }
        return request
    }
}

private struct HTTPEnvelope<T: Codable>: Codable {
    let data: T?
    let message: String?
}
