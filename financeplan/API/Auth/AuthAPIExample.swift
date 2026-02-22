import Foundation
import StockPlanShared
import AnyAPI


typealias Parameters = [String: Any]

protocol Endpoint {
    associatedtype Response

    var method: HTTPMethod { get }
    var path: String { get }

    func asParameters() throws -> Parameters
}

/// AnyAPI-style endpoints that reuse shared auth models from StockPlanShared.
/// Backend routes: /auth/login and /auth/register.

struct LoginEndpoint: Endpoint {
    typealias Response = AuthResponse

    let email: String
    let password: String

    var method: HTTPMethod { .post }
    var path: String { "/auth/login" }

    func asParameters() throws -> Parameters {
        let payload = AuthLoginRequest(email: email, password: password)

        var params: Parameters = [:]
        params["email"] = payload.email
        params["password"] = payload.password
        return params
    }
}

struct RegisterEndpoint: Endpoint {
    typealias Response = AuthResponse

    let username: String
    let password: String
    let email: String
    let firstName: String
    let lastName: String
    let dateOfBirth: Date

    var method: HTTPMethod { .post }
    var path: String { "/auth/register" }

    func asParameters() throws -> Parameters {
        let payload = AuthRegisterRequest(
            username: username,
            password: password,
            email: email,
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: dateOfBirth
        )

        var params: Parameters = [:]
        params["username"] = payload.username
        params["password"] = payload.password
        params["email"] = payload.email
        params["firstName"] = payload.firstName
        params["lastName"] = payload.lastName
        params["dateOfBirth"] = ISO8601DateFormatter().string(from: payload.dateOfBirth)
        return params
    }
}
