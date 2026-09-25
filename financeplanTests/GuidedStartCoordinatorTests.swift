import Foundation
import StockPlanShared
import Testing
@testable import financeplan

actor FakeOnboardingClient: OnboardingClientProtocol {
  var state: OnboardingStateDTO
  var failPatch = false
  private(set) var getCount = 0

  init(_ state: OnboardingStateDTO) { self.state = state }

  func set(_ state: OnboardingStateDTO) { self.state = state }
  func setFailPatch(_ fail: Bool) { failPatch = fail }

  func get() async throws -> OnboardingStateDTO {
    getCount += 1
    return state
  }

  func patch(_ request: OnboardingPatchRequest) async throws -> OnboardingStateDTO {
    if failPatch { throw URLError(.notConnectedToInternet) }
    if let dismissed = request.guidedStartDismissed {
      state = OnboardingStateDTO(
        funnelStep: state.funnelStep, funnelCompletedAt: state.funnelCompletedAt,
        addHoldingCompleted: state.addHoldingCompleted, setBudgetCompleted: state.setBudgetCompleted,
        setGoalCompleted: state.setGoalCompleted, guidedStartDismissedAt: dismissed ? Date() : nil
      )
    }
    return state
  }
}

@MainActor
final class RecordingAnalytics: GuidedStartAnalytics {
  var events: [(name: String, properties: [String: Any]?)] = []
  func capture(_ event: String, properties: [String: Any]?) { events.append((event, properties)) }
  var names: [String] { events.map(\.name) }
}

@MainActor
final class Clock {
  var now = Date(timeIntervalSince1970: 1_800_000_000)
  var slept: [Duration] = []
}

@MainActor
private func state(holding: Bool = false, budget: Bool = false, goal: Bool = false, funnelDone: Bool = true, dismissed: Bool = false) -> OnboardingStateDTO {
  OnboardingStateDTO(
    funnelStep: funnelDone ? "done" : "import",
    funnelCompletedAt: funnelDone ? Date(timeIntervalSince1970: 1_700_000_000) : nil,
    addHoldingCompleted: holding, setBudgetCompleted: budget, setGoalCompleted: goal,
    guidedStartDismissedAt: dismissed ? Date(timeIntervalSince1970: 1_700_000_000) : nil
  )
}

/// Everything a test may need to drive or inspect a coordinator. A struct rather
/// than a five-member tuple, which SwiftLint's large_tuple rule rejects.
private struct Harness {
  let coordinator: GuidedStartCoordinator
  let client: FakeOnboardingClient
  let store: OnboardingStateStore
  let analytics: RecordingAnalytics
  let clock: Clock
}

@MainActor
private func makeCoordinator(_ initial: OnboardingStateDTO) -> Harness {
  let client = FakeOnboardingClient(initial)
  let store = OnboardingStateStore(client: client)
  store.apply(initial)
  let analytics = RecordingAnalytics()
  let clock = Clock()
  let coordinator = GuidedStartCoordinator(
    client: client,
    telemetry: GuidedStartTelemetry(analytics: analytics),
    now: { clock.now },
    sleep: { duration in
      clock.slept.append(duration)
      clock.now += Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
      await Task.yield()
    },
    snapshot: { store.state },
    applySnapshot: { store.apply($0) }
  )
  return Harness(coordinator: coordinator, client: client, store: store, analytics: analytics, clock: clock)
}

@Suite("Guided start coordinator")
@MainActor
struct GuidedStartCoordinatorTests {
  @Test("Card visibility follows the contract")
  func visibility() {
    #expect(makeCoordinator(state()).coordinator.isCardVisible)
    #expect(makeCoordinator(state(funnelDone: false)).coordinator.isCardVisible == false)
    #expect(makeCoordinator(state(dismissed: true)).coordinator.isCardVisible == false)
    #expect(makeCoordinator(state(holding: true, budget: true, goal: true)).coordinator.isCardVisible == false)
  }

  @Test("Starting a done step skips ahead and asks for that step's tab")
  func skipAhead() async {
    let harness = makeCoordinator(state(holding: true))
    let coordinator = harness.coordinator
    let analytics = harness.analytics
    await coordinator.start(.addHolding)
    #expect(coordinator.activeStep == .setBudget)
    #expect(coordinator.requestedTab == .expenses)
    #expect(analytics.names == ["guided_start_step_started"])
    #expect(analytics.events[0].properties?["step"] as? String == "set_budget")
    coordinator.skip()
  }

  @Test("Polls on 1s, 2s, 4s, 8s, then 10s, and times out after 5 minutes")
  func pollScheduleAndTimeout() async {
    let harness = makeCoordinator(state())
    let coordinator = harness.coordinator
    let analytics = harness.analytics
    let clock = harness.clock
    await coordinator.start(.addHolding)
    await coordinator.settle()
    #expect(Array(clock.slept.prefix(6)) == [.seconds(1), .seconds(2), .seconds(4), .seconds(8), .seconds(10), .seconds(10)])
    #expect(clock.slept.count == 33)
    #expect(analytics.names.last == "guided_start_step_timed_out")
    let timedOut = analytics.events.first { $0.name == "guided_start_step_timed_out" }
    #expect((timedOut?.properties?["elapsed_ms"] as? Int ?? 0) >= 300_000)
    #expect(coordinator.phase == .idle)
  }

  @Test("A local action polls at once and completes without completed_elsewhere")
  func localCompletion() async {
    let harness = makeCoordinator(state())
    let coordinator = harness.coordinator
    let client = harness.client
    let analytics = harness.analytics
    await coordinator.start(.addHolding)
    await client.set(state(holding: true))
    coordinator.noteUserAction(.addHolding)
    await coordinator.settle()
    let completed = analytics.events.first { $0.name == "guided_start_step_completed" }
    #expect(completed?.properties?["completed_elsewhere"] as? Bool == false)
    #expect(coordinator.phase == .idle)
  }

  @Test("A latch flipping without a local action is completed elsewhere")
  func elsewhereCompletion() async {
    let harness = makeCoordinator(state())
    let coordinator = harness.coordinator
    let client = harness.client
    let analytics = harness.analytics
    await coordinator.start(.setGoal)
    await client.set(state(goal: true))
    await coordinator.settle()
    let completed = analytics.events.first { $0.name == "guided_start_step_completed" }
    #expect(completed?.properties?["completed_elsewhere"] as? Bool == true)
  }

  @Test("Finishing the last step shows the completed card, then fires completed once")
  func lastStep() async {
    let harness = makeCoordinator(state(holding: true, budget: true))
    let coordinator = harness.coordinator
    let client = harness.client
    let analytics = harness.analytics
    await coordinator.start(.setGoal)
    await client.set(state(holding: true, budget: true, goal: true))
    await coordinator.settle()
    #expect(coordinator.phase == .finished)
    #expect(coordinator.isCardVisible)
    #expect(analytics.names.filter { $0 == "guided_start_completed" }.count == 1)
    await coordinator.dismissCard()
    #expect(coordinator.isCardVisible == false)
  }

  @Test("A failed dismiss restores the card, says so, and reports no dismissal")
  func dismissFailure() async {
    let harness = makeCoordinator(state())
    let coordinator = harness.coordinator
    let client = harness.client
    let analytics = harness.analytics
    await client.setFailPatch(true)
    await coordinator.dismissCard()
    #expect(coordinator.isCardVisible)
    #expect(coordinator.inlineMessage == GuidedStartCopy.dismissFailed)
    #expect(analytics.names.contains("guided_start_dismissed") == false)
  }

  @Test("A dismissal is reported once the server has it, like the web")
  func dismissReportedAfterPatch() async {
    let harness = makeCoordinator(state())
    let coordinator = harness.coordinator
    let analytics = harness.analytics
    await coordinator.dismissCard()
    #expect(coordinator.isCardVisible == false)
    #expect(analytics.names == ["guided_start_dismissed"])
  }

  @Test("An action with no open step refreshes the card once")
  func actionWithoutStepRefreshes() async {
    let harness = makeCoordinator(state())
    let coordinator = harness.coordinator
    let client = harness.client
    let store = harness.store
    await client.set(state(holding: true))
    coordinator.noteUserAction(.addHolding)
    await coordinator.settle()
    #expect(await client.getCount == 1)
    #expect(store.state?.addHoldingCompleted == true)
  }

  @Test("An action for a different open step does not add a refresh")
  func actionForOtherStepDoesNotRefresh() async {
    let harness = makeCoordinator(state())
    let coordinator = harness.coordinator
    let client = harness.client
    await coordinator.start(.addHolding) // one get: start refreshes first
    coordinator.noteUserAction(.setGoal)
    #expect(await client.getCount == 1)
    coordinator.skip()
  }

  @Test("A dismissal from another device waits for the open step")
  func dismissalElsewhereWaitsForOpenStep() async {
    let harness = makeCoordinator(state())
    let coordinator = harness.coordinator
    let store = harness.store
    await coordinator.start(.addHolding)
    store.apply(state(dismissed: true))
    #expect(coordinator.isCardVisible, "an engaged step keeps the card")
    coordinator.skip()
    #expect(coordinator.isCardVisible == false)
  }

  @Test("Show me around on a finished wizard shows the completed card this session")
  func showMeAround() async {
    let harness = makeCoordinator(state(holding: true, budget: true, goal: true, dismissed: true))
    let coordinator = harness.coordinator
    let analytics = harness.analytics
    await coordinator.showMeAround()
    #expect(coordinator.isCardVisible)
    #expect(analytics.names == ["guided_start_reopened"])
  }
}
