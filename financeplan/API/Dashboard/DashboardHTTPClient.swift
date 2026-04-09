import AnyAPI
import Foundation
import OSLog
import StockPlanShared

private let dashboardHTTPLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
    category: "DashboardHTTPClient"
)

struct DashboardHTTPClient {
    enum Error: LocalizedError, Equatable {
        case invalidResponse
        case invalidStatus(Int)
        case unauthorized(String?)
        case api(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "Invalid server response."
            case let .invalidStatus(code): return "Request failed (\(code))."
            case let .unauthorized(message): return message ?? "Your session expired."
            case let .api(message): return message
            }
        }
    }

    let baseURL: URL
    let session: URLSession
    let authTokenProvider: () -> String?

    init(baseURL: URL, session: URLSession = .shared, authTokenProvider: @escaping () -> String? = { nil }) {
        self.baseURL = baseURL
        self.session = session
        self.authTokenProvider = authTokenProvider
    }

    func getDashboard() async throws -> DashboardResponse {
        try await call(GetDashboardEndpoint())
    }

    func getInsights() async throws -> DashboardInsightsResponse {
        try await call(GetDashboardInsightsEndpoint())
    }

    private func call<E: Endpoint>(_ endpoint: E) async throws -> E.Response where E.Response: Codable {
        let request = try makeURLRequest(for: endpoint)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.invalidResponse
        }

        dashboardHTTPLogger.debug("Dashboard response [\(endpoint.path)] status=\(httpResponse.statusCode)")

        guard (200..<300).contains(httpResponse.statusCode) else {
            let decoder = JSONDecoder.stockPlanShared
            if let envelope = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw Error.api(envelope.error)
            }
            if httpResponse.statusCode == 401 { throw Error.unauthorized(nil) }
            throw Error.invalidStatus(httpResponse.statusCode)
        }

        do {
            return try endpoint.decode(data)
        } catch {
            if let envelope = try? endpoint.decoder.decode(APIEnvelope<E.Response>.self, from: data), let payload = envelope.data {
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
        guard let url = urlComponents?.url else { throw Error.invalidResponse }

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
