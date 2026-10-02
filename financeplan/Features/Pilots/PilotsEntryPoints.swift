import StockPlanShared
import SwiftUI

/// The "Follow a pilot" row in the portfolio workspace.
struct PilotsEntryRow: View {
  let followCount: Int

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "person.2.wave.2")
        .foregroundStyle(Color.accentColor)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 3) {
        Text("Follow a pilot").font(.headline)
        if followCount == 0 {
          Text("Mirror a politician's or a fund's disclosed trades in a simulation")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Text("Following ^[\(followCount) pilot](inflect: true)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }
}

/// Shown on a portfolio a pilot follow manages.
struct PilotFollowBanner: View {
  let follow: PilotFollowResponse

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Label("Following \(follow.pilot.displayName)", systemImage: "person.2.wave.2")
        .font(.headline)
      if follow.status == .paused {
        Text("Paused. Holdings stay as they are until you resume.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      } else {
        Text("Simulated. Trades mirror this pilot's disclosures, priced when Norviq sees them.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Text("You can't edit holdings by hand while you follow.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("portfolio.pilotFollowBanner")
  }
}
