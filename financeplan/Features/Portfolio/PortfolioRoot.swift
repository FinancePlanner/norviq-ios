import SwiftUI
import Factory
import StockPlanShared

@MainActor
struct PortfolioRoot: View {
  @Environment(\.colorScheme) private var colorScheme
  @Binding var isSettingsPresented: Bool
  @Binding var pendingOpenSymbol: String?
  @InjectedObservable(\Container.billingManager) private var billingManager
  @StateObject private var portfolioViewModel = PortfolioViewModel()

  var body: some View {
    NavigationStack {
      PortfolioScreen(
        pendingOpenSymbol: $pendingOpenSymbol
      )
      .environmentObject(portfolioViewModel)
      .navigationTitle("Portfolio")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Settings", systemImage: "gearshape") {
            isSettingsPresented = true
          }
          .labelStyle(.iconOnly)
          .buttonStyle(.bordered)
          .tint(AppTheme.Colors.tint(for: colorScheme))
          .accessibilityLabel(LocalizedStringKey("Open settings"))
        }
        ToolbarItem(placement: .topBarTrailing) {
          NavigationLink(destination: ProGateView(billingManager: billingManager) { ScenarioPlanningScreen() }) {
            Label("Scenario planning", systemImage: "chart.xyaxis.line")
          }
            .labelStyle(.iconOnly)
            .accessibilityLabel("Open scenario planning")
        }
      }
    }
  }
}
