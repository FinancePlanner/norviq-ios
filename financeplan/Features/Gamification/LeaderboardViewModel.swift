import Factory
import Foundation
import Observation

/// One friends-only leaderboard: the caller and their friends who opted in,
/// ranked by the server. Values are percentages or counts, never money.
@MainActor
@Observable
final class LeaderboardViewModel {
  var metric: LeaderboardMetric = .xp
  var period: LeaderboardPeriod = .week
  private(set) var response: LeaderboardResponse?
  private(set) var isLoading = false
  var errorMessage: String?

  private let service: any GamificationServicing
  /// Bumped per request so a slow answer for an old selection can't
  /// overwrite a newer one.
  private var requestID = 0

  init(service: any GamificationServicing = Container.shared.gamificationService()) {
    self.service = service
  }

  var entries: [LeaderboardEntry] {
    guard let response, response.metric == metric, response.period == period else { return [] }
    return response.entries
  }

  /// Only the caller on the board: nobody to compare with yet.
  var isAlone: Bool {
    entries.allSatisfy(\.isMe)
  }

  var showsReturnPercentNote: Bool { metric == .returnPercent }

  func load() async {
    requestID += 1
    let current = requestID
    let requestedMetric = metric
    let requestedPeriod = period
    isLoading = true
    defer { if current == requestID { isLoading = false } }
    do {
      let result = try await service.leaderboard(metric: requestedMetric, period: requestedPeriod)
      guard current == requestID else { return }
      response = result
      errorMessage = nil
    } catch {
      // A newer selection cancelled this one; its own load reports errors.
      guard current == requestID, !Task.isCancelled, !(error is CancellationError) else { return }
      errorMessage = error.localizedDescription
    }
  }

  /// Changes whenever the selection does; the view reloads on it.
  var selectionKey: String { "\(metric.rawValue)-\(period.rawValue)" }

  /// How a value reads in a row: "+4.2%" for return, a plain count otherwise.
  static func formattedValue(_ value: Double, metric: LeaderboardMetric) -> String {
    switch metric {
    case .returnPercent:
      let percent = (value / 100).formatted(.percent.precision(.fractionLength(1)))
      return value > 0 ? "+\(percent)" : percent
    case .xp:
      return String(localized: "\(Int(value.rounded())) XP")
    case .checkInStreak:
      return String(localized: "\(Int(value.rounded())) days")
    case .budgetStreak:
      return String(localized: "\(Int(value.rounded())) months")
    }
  }
}
