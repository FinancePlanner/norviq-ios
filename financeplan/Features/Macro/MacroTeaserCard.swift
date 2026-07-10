import Factory
import StockPlanShared
import SwiftUI

/// Dashboard teaser: current US inflation headline with a link into the full
/// MacroScreen. Loads once, fails silent (card hides itself when no data).
struct MacroTeaserCard: View {
  @State private var snapshot: InflationSnapshotResponse?
  @State private var hasLoaded = false

  private let macroService: any MacroServicing = Container.shared.macroService()

  var body: some View {
    Group {
      if let snapshot {
        NavigationLink {
          MacroScreen()
        } label: {
          GlassCard {
            HStack(spacing: 12) {
              Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title3)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

              VStack(alignment: .leading, spacing: 2) {
                Text("Inflation — \(snapshot.country)")
                  .typography(.small, weight: .semibold)
                Text(teaserDetail(for: snapshot))
                  .typography(.nano)
                  .foregroundStyle(.secondary)
              }

              Spacer()

              Text("\(snapshot.headline.nowValue, specifier: "%.2f")%")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(.tint)

              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            }
          }
        }
        .buttonStyle(.plain)
      }
    }
    .task {
      guard !hasLoaded else { return }
      hasLoaded = true
      snapshot = try? await macroService.getCurrentInflation(country: nil)
    }
  }

  private func teaserDetail(for snapshot: InflationSnapshotResponse) -> String {
    if let mover = snapshot.topMovers.first {
      return String(localized: "Top mover: \(mover.category) \(mover.changeYoY > 0 ? "+" : "")\(mover.changeYoY.formatted(.number.precision(.fractionLength(1))))%")
    }
    return snapshot.headline.name
  }
}
