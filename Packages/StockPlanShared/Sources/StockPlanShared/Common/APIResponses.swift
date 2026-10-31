import Foundation

public struct APISuccess: Codable, Sendable, Equatable {
    public let success: Bool

    public init(success: Bool = true) {
        self.success = success
    }
}

public struct APIMessageResponse: Codable, Sendable, Equatable {
    public let success: Bool
    public let message: String

    public init(success: Bool = true, message: String) {
        self.success = success
        self.message = message
    }
}

public struct APIErrorResponse: Codable, Sendable, Equatable {
    public let success: Bool
    public let error: String
    public let code: String?

    public init(success: Bool = false, error: String, code: String? = nil) {
        self.success = success
        self.error = error
        self.code = code
    }
}

public struct APIEnvelope<T: Codable & Sendable>: Codable, Sendable {
    public let success: Bool
    public let data: T?
    public let message: String?

    public init(success: Bool = true, data: T? = nil, message: String? = nil) {
        self.success = success
        self.data = data
        self.message = message
    }
}

extension APIEnvelope: Equatable where T: Equatable {}

public struct EmptyAPIResponse: Codable, Sendable, Equatable {
    public init() {}
}
