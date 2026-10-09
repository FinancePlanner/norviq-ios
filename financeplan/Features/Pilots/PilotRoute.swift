import StockPlanShared
import SwiftUI

/// Pilot screens pushed onto the Portfolio stack by value, so they share the
/// stack's `NavigationPath` with its other routes instead of being pushed as
/// views the path can't represent.
///
/// Each case carries the snapshot the screen opens with, exactly as the
/// view-based links did. Identity is the slug or follow id alone: the shared
/// DTOs are only `Equatable`, and a refreshed snapshot of the same pilot or
/// follow is still the same destination.
enum PilotRoute: Hashable {
  case browse
  case pilot(PilotSummary)
  case follow(PilotFollowResponse)

  static func == (lhs: PilotRoute, rhs: PilotRoute) -> Bool {
    switch (lhs, rhs) {
    case (.browse, .browse): true
    case let (.pilot(a), .pilot(b)): a.slug == b.slug
    case let (.follow(a), .follow(b)): a.id == b.id
    default: false
    }
  }

  func hash(into hasher: inout Hasher) {
    switch self {
    case .browse:
      hasher.combine(0)
    case let .pilot(pilot):
      hasher.combine(1)
      hasher.combine(pilot.slug)
    case let .follow(follow):
      hasher.combine(2)
      hasher.combine(follow.id)
    }
  }
}

extension View {
  /// Registers the pilot screens on the enclosing `NavigationStack`. Apply
  /// once per stack that links to a `PilotRoute`.
  func pilotDestinations() -> some View {
    navigationDestination(for: PilotRoute.self) { route in
      switch route {
      case .browse: PilotsBrowseScreen()
      case let .pilot(pilot): PilotDetailScreen(pilot: pilot)
      case let .follow(follow): PilotFollowDetailScreen(follow: follow)
      }
    }
  }
}
