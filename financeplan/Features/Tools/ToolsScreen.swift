import Factory
import SwiftUI

/// One place for the calculators and planners that otherwise sit behind the
/// Portfolio toolbar. Nothing moves: the existing menu entries stay, and each
/// tool keeps its own gate.
struct ToolsScreen: View {
  @InjectedObservable(\Container.billingManager) private var billingManager

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        VigilPageHeader(
          watch: .wealthPlan,
          title: "Tools",
          subtitle: "Calculators and planners for your money, in one place."
        )

        ForEach(ToolsCatalog.entries) { entry in
          NavigationLink(value: entry.route) {
            ToolRow(entry: entry, showsProMark: entry.requiresPro && !billingManager.isPro)
          }
          .buttonStyle(.plain)
        }
      }
      .padding()
    }
    .vigilScreenBackground()
    .vigilNavigationTitle("Tools")
    .vigilInlineNavigationBar()
  }
}

private struct ToolRow: View {
  @Environment(\.colorScheme) private var colorScheme
  let entry: ToolEntry
  let showsProMark: Bool

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: entry.systemImage)
        .font(.title3)
        .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
        .frame(width: 28)
        .accessibilityHidden(true)

      // `Text(String)` skips localization, so the catalog's strings go through
      // a key to reach the string catalog.
      VStack(alignment: .leading, spacing: 3) {
        Text(LocalizedStringKey(entry.title))
          .font(.headline)
        Text(LocalizedStringKey(entry.question))
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.leading)
      }

      Spacer(minLength: 0)

      if showsProMark {
        Text("Pro")
          .font(.caption.weight(.semibold))
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
      }

      Image(systemName: "chevron.right")
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      AppTheme.Colors.cardBackground(for: colorScheme),
      in: RoundedRectangle(cornerRadius: 20, style: .continuous)
    )
  }
}

/// `toolsDestinations()` is a modifier and can't hold injected state, so the
/// billing manager for the Pro gate is resolved here.
private struct ToolsRebalancingDestination: View {
  @InjectedObservable(\Container.billingManager) private var billingManager

  var body: some View {
    ProGateView(billingManager: billingManager) { RebalancingRulesScreen() }
  }
}

extension View {
  /// Registers the hub and its tools on the enclosing `NavigationStack`. Apply
  /// once per stack that links to a `ToolsRoute`.
  func toolsDestinations() -> some View {
    navigationDestination(for: ToolsRoute.self) { route in
      switch route {
      case .hub: ToolsScreen()
      case .grow: GrowScreen()
      case .retire: RetireScreen()
      case .terminalPositions: TerminalPositionsScreen()
      case .simulator: PortfolioSimulatorScreen()
      case .rebalancingRules: ToolsRebalancingDestination()
      }
    }
  }
}
