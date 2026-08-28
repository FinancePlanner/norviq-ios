import Foundation
import StockPlanShared

/// Which screen a summary is about.
///
/// Mirrors the backend's `AIViewScope`. App-local on purpose, following
/// `WhyMovedDTOs`: putting it in `norviq-shared` would make every new screen a
/// package tag plus a release in both repos, and the two are already on
/// different pins.
nonisolated enum AIViewScope: String, Codable, CaseIterable, Sendable {
    case home
    case portfolio
    case expenses
    case crypto
    case markets
    case economy
    case reports
    case tax

    /// Used in the sheet title and the loading line.
    var displayName: String {
        switch self {
        case .home: "dashboard"
        case .portfolio: "portfolio"
        case .expenses: "spending"
        case .crypto: "crypto holdings"
        case .markets: "markets"
        case .economy: "economy"
        case .reports: "reports"
        case .tax: "tax position"
        }
    }

    /// Seeds the composer when the reader continues into Q.
    ///
    /// Deliberately free of numbers and of anything personal: a linked Telegram
    /// chat is the same thread, so this sentence can end up in a scrollback the
    /// reader did not expect it in.
    var followUpPrompt: String {
        "Tell me more about my \(displayName)."
    }
}

/// A generated summary of one screen.
///
/// `scope` decodes as a plain `String` rather than the enum so that a backend
/// which learns a ninth screen does not break this build — an unknown case in a
/// bare `String, Codable` enum is a hard `DecodingError`, and that is exactly
/// the trap `AIInsightKind` sets. Rendering uses the string; only the request
/// side needs the enum.
/// `nonisolated` because the app target defaults to MainActor isolation, so a
/// synthesized conformance would otherwise be actor-isolated and could not
/// satisfy a `Sendable` requirement. Same reason as `WhyMovedDTOs`.
///
/// `Codable` rather than `Decodable`: `Endpoint` is itself `Encodable` and
/// `BaseHTTPClient.call` requires the same of `Response`. Nothing here is ever
/// sent -- the encode side exists only to satisfy that constraint, exactly as
/// it does for the shared insight DTOs.
nonisolated struct AIViewSummaryResponse: Codable, Equatable, Sendable {
    let scope: String
    let title: String
    let body: String
    let highlights: [AIInsightHighlight]
    let disclaimer: String
    let generatedAt: Date
    let isCached: Bool
}
