import AnyAPI
import Foundation
import StockPlanShared

protocol ActivityURLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: ActivityURLSessionProtocol {}

struct ActivityHTTPClient: ActivityURLSessionProtocol {
    enum Error: Swift.Error {
        case invalidResponse
        case api(String)

        var isUnauthorized: Bool {
            if case .invalidResponse = self { return true }
            return false
        }
    }

    private let session: ActivityURLSessionProtocol
    private let baseURL: URL
    private let authTokenProvider: () -> String?

    init(
        baseURL: URL,
        session: ActivityURLSessionProtocol = URLSession.shared,
        authTokenProvider: @escaping () -> String? = { nil }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authTokenProvider = authTokenProvider
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }

    func fetchActivities(limit: Int? = nil) async throws -> [UserActivityResponse] {
        try await call(GetActivitiesEndpoint(limit: limit))
    }

    private func call<E: Endpoint>(_ endpoint: E) async throws -> E.Response where E.Response: Codable {
        let request = try makeURLRequest(for: endpoint)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.invalidResponse
        }

        if (200...299).contains(httpResponse.statusCode) {
            return try endpoint.decode(data)
        } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else {
            if let envelope = try? endpoint.decoder.decode(APIEnvelope<E.Response>.self, from: data),
               let message = envelope.message {
                throw Error.api(message)
            }
            throw Error.invalidResponse
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

        if let token = authTokenProvider(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if endpoint.method != .get, !parameters.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        }

        return request
    }
}
