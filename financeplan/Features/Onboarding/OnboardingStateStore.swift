import Foundation
import Observation
import OSLog
import StockPlanShared

/// The signed-in user's server-side onboarding row: funnel position for
/// ContentView, guided-start progress for Home. Contract:
/// norviq-shared/docs/guided-start.md.
@Observable @MainActor
final class OnboardingStateStore {
  private(set) var state: OnboardingStateDTO?

  @ObservationIgnored private let client: any OnboardingClientProtocol
  @ObservationIgnored private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "OnboardingStateStore")

  init(client: any OnboardingClientProtocol) {
    self.client = client
  }

  /// Returns the fresh state, or nil when it could not be read. A failed read
  /// keeps whatever was already known.
  @discardableResult
  func refresh() async -> OnboardingStateDTO? {
    do {
      let fresh = try await client.get()
      state = fresh
      return fresh
    } catch {
      logger.warning("onboarding refresh failed: \(error.localizedDescription, privacy: .public)")
      return nil
    }
  }

  func apply(_ state: OnboardingStateDTO) {
    self.state = state
  }

  func patch(_ request: OnboardingPatchRequest) async throws {
    state = try await client.patch(request)
  }

  /// Best-effort, like the web: a failed write costs a resume, not the flow.
  func recordFunnelStep(_ step: OnboardingFunnelStep) async {
    try? await patch(OnboardingPatchRequest(funnelStep: step.rawValue))
  }

  func completeFunnel() async {
    try? await patch(OnboardingPatchRequest(funnelCompleted: true))
  }

  func reset() {
    state = nil
  }
}
