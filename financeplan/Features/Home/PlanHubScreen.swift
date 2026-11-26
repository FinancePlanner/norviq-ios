import Factory
import SwiftUI

/// The Plan tab (spec §7.11): where am I heading? Goals, Your future, Tax,
/// and "New goal" in the toolbar.
struct PlanHubScreen: View {
  @Binding var path: NavigationPath
  @InjectedObservable(\Container.billingManager) private var billingManager
  @State private var isPaywallPresented = false

  var body: some View {
    NavigationStack(path: $path) {
      List {
        HubSectionsView(sections: PlanHubModel.sections(), userIsPro: billingManager.isPro, onTap: handle)
      }
      .vigilListChrome()
      .navigationTitle(Text(AppTab.plan.title))
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          // Opens Goals, where the goal-creation flow already lives.
          Button("New goal") {
            path.append(AppDestination.goals)
          }
          .accessibilityIdentifier("plan.newGoal")
        }
      }
      // Friends lives in More, so Plan has no invite or section to hand on.
      .navigationDestination(for: AppDestination.self) {
        destinationView($0, path: $path, pendingInviteCode: .constant(nil), pendingSocialSection: .constant(nil))
      }
      // Tools links to its tools by `ToolsRoute`.
      .toolsDestinations()
      .sheet(isPresented: $isPaywallPresented) {
        PaywallView(billingManager: billingManager)
      }
    }
  }

  private func handle(_ row: HubRow) {
    switch row.tap(userIsPro: billingManager.isPro) {
    case .paywall:
      isPaywallPresented = true
    case let .perform(.push(destination)):
      path.append(destination)
    case .perform(.selectTab):
      assertionFailure("No Plan row leaves the tab")
    }
  }
}
