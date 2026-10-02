import Foundation
import StockPlanShared

/// Client-side copy of the server's follow rules. Advisory only: the server
/// enforces every one of them and its answer wins.
enum PilotFollowRules {
  static let freeFollowLimit = 1
  static let proFollowLimit = 10
  static let maxStartingCapital: Double = 10_000_000

  enum Block: Equatable {
    /// No book yet (`holdingsCount == 0`); the server would answer 409.
    case noTradesYet
    /// Free and already at the one free follow.
    case needsPro
    /// Pro and at the follow limit.
    case atLimit
  }

  static func block(for pilot: PilotSummary, isPro: Bool, followCount: Int) -> Block? {
    if pilot.holdingsCount == 0 { return .noTradesYet }
    if isPro { return followCount >= proFollowLimit ? .atLimit : nil }
    return followCount >= freeFollowLimit ? .needsPro : nil
  }

  /// Nil when the amount is acceptable for a portfolio follow.
  static func capitalProblem(_ capital: Double?) -> String? {
    guard let capital else { return String(localized: "Enter a starting amount.") }
    guard capital > 0 else { return String(localized: "Enter an amount above zero.") }
    guard capital <= maxStartingCapital else { return String(localized: "The most you can start with is $10,000,000.") }
    return nil
  }
}

/// What the follow sheet does with a failed `POST /v1/pilot-follows`.
enum PilotFollowFailure: Equatable {
  /// Show the paywall.
  case needsPro
  /// Show this sentence inline.
  case message(String)

  static func from(_ error: any Error, isPro: Bool) -> PilotFollowFailure {
    // The billing 403 carries the feature that hit its limit in a structured
    // field; the client decodes it, so the reason text is never parsed.
    if case let .upgradeRequired(feature, _)? = error as? PilotsHTTPClient.Error {
      if feature == "portfolio_lists" {
        return .message(String(localized: "You've reached the portfolio limit for your plan. Archive a portfolio, then try again."))
      }
      return isPro
        ? .message(String(localized: "You're following 10 pilots, the most your plan allows. Stop following one to add another."))
        : .needsPro
    }
    guard case let .rejected(status, message)? = error as? PilotsHTTPClient.Error else {
      return .message(error.localizedDescription)
    }
    let reason = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    switch status {
    case 403:
      // Not the billing body: the token lacks the scope for this route.
      return .message(String(localized: "Your sign-in can't make this change. Sign out and back in, then try again."))
    case 404:
      if reason.isEmpty || reason == "Not Found" {
        return .message(String(localized: "Following pilots isn't available right now."))
      }
      return .message(reason)
    case 400:
      return .message(reason.isEmpty ? String(localized: "Starting capital must be more than $0 and at most $10,000,000.") : reason)
    case 409:
      return .message(reason.isEmpty ? String(localized: "No trades seen yet for this pilot. Try again later.") : reason)
    case 422:
      return .message(reason.isEmpty ? String(localized: "Choose an empty watchlist, or let Norviq create one.") : reason)
    default:
      return .message(error.localizedDescription)
    }
  }
}
