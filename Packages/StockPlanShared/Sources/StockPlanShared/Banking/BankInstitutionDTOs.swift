import Foundation

/// A selectable bank for the hosted-link flow (GoCardless / Enable Banking, EU).
/// Plaid selects the institution inside its own SDK, so this list is populated
/// only for providers that need the client to choose a bank first.
public struct BankInstitutionResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let bic: String?
    public let logoURL: String?
    /// ISO 3166-1 alpha-2 country the institution belongs to.
    public let country: String?
    /// The aggregator's integration with this bank is new (Enable Banking "beta").
    public let beta: Bool?

    public init(
        id: String,
        name: String,
        bic: String? = nil,
        logoURL: String? = nil,
        country: String? = nil,
        beta: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.bic = bic
        self.logoURL = logoURL
        self.country = country
        self.beta = beta
    }
}

/// Request to begin a hosted link for a chosen institution.
public struct BankHostedLinkRequest: Codable, Sendable, Equatable {
    public let institutionId: String
    /// App/web URL the backend redirects back to after consent.
    public let redirectURI: String

    public init(institutionId: String, redirectURI: String) {
        self.institutionId = institutionId
        self.redirectURI = redirectURI
    }
}
