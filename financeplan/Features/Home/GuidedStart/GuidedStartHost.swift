import Factory
import SwiftUI

extension GuidedStartCoordinator {
  /// Production wiring. One per signed-in shell, created in HomeScreen.
  static func live(
    store: OnboardingStateStore = Container.shared.onboardingStateStore(),
    client: any OnboardingClientProtocol = Container.shared.onboardingClient()
  ) -> GuidedStartCoordinator {
    GuidedStartCoordinator(
      client: client,
      telemetry: GuidedStartTelemetry(),
      snapshot: { store.state },
      applySnapshot: { store.apply($0) }
    )
  }
}

private struct ReopenGuidedStartKey: EnvironmentKey {
  static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
  /// Settings › "Show me around". Nil outside the signed-in shell.
  var norviqReopenGuidedStart: (() -> Void)? {
    get { self[ReopenGuidedStartKey.self] }
    set { self[ReopenGuidedStartKey.self] = newValue }
  }
}
