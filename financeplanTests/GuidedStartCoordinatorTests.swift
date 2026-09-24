import Foundation
import StockPlanShared
import Testing
@testable import financeplan

actor FakeOnboardingClient: OnboardingClientProtocol {
  var state: OnboardingStateDTO
  var failPatch = false

  init(_ state: OnboardingStateDTO) { self.state = state }

  func set(_ state: OnboardingStateDTO) { self.state = state }
  func setFailPatch(_ fail: Bool) { failPatch = fail }

  func get() async throws -> OnboardingStateDTO { state }

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

@MainActor
private func makeCoordinator(_ initial: OnboardingStateDTO) -> (GuidedStartCoordinator, FakeOnboardingClient, OnboardingStateStore, RecordingAnalytics, Clock) {
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
  return (coordinator, client, store, analytics, clock)
}

@Suite("Guided start coordinator")
@MainActor
struct GuidedStartCoordinatorTests {
  @Test("Card visibility follows the contract")
  func visibility() {
    #expect(makeCoordinator(state()).0.isCardVisible)
    #expect(makeCoordinator(state(funnelDone: false)).0.isCardVisible == false)
    #expect(makeCoordinator(state(dismissed: true)).0.isCardVisible == false)
    #expect(makeCoordinator(state(holding: true, budget: true, goal: true)).0.isCardVisible == false)
  }

  @Test("Starting a done step skips ahead and asks for that step's tab")
  func skipAhead() async {
    let (coordinator, _, _, analytics, _) = makeCoordinator(state(holding: true))
    await coordinator.start(.addHolding)
    #expect(coordinator.activeStep == .setBudget)
    #expect(coordinator.requestedTab == .expenses)
    #expect(analytics.names == ["guided_start_step_started"])
    #expect(analytics.events[0].properties?["step"] as? String == "set_budget")
    coordinator.skip()
  }

  @Test("Polls on 1s, 2s, 4s, 8s, then 10s, and times out after 5 minutes")
  func pollScheduleAndTimeout() async {
    let (coordinator, _, _, analytics, clock) = makeCoordinator(state())
    await coordinator.start(.addHolding)
    await coordinator.settle()
    #expect(Array(clock.slept.prefix(6)) == [.seconds(1), .seconds(2), .seconds(4), .seconds(8), .seconds(10), .seconds(10)])
    #expect(analytics.names.last == "guided_start_step_timed_out")
    #expect(coordinator.phase == .idle)
  }

  @Test("A local action polls at once and completes without completed_elsewhere")
  func localCompletion() async {
    let (coordinator, client, _, analytics, _) = makeCoordinator(state())
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
    let (coordinator, client, _, analytics, _) = makeCoordinator(state())
    await coordinator.start(.setGoal)
    await client.set(state(goal: true))
    await coordinator.settle()
    let completed = analytics.events.first { $0.name == "guided_start_step_completed" }
    #expect(completed?.properties?["completed_elsewhere"] as? Bool == true)
  }

  @Test("Finishing the last step shows the completed card, then fires completed once")
  func lastStep() async {
    let (coordinator, client, _, analytics, _) = makeCoordinator(state(holding: true, budget: true))
    await coordinator.start(.setGoal)
    await client.set(state(holding: true, budget: true, goal: true))
    await coordinator.settle()
    #expect(coordinator.phase == .finished)
    #expect(coordinator.isCardVisible)
    #expect(analytics.names.filter { $0 == "guided_start_completed" }.count == 1)
  }

  @Test("A failed dismiss restores the card and says so")
  func dismissFailure() async {
    let (coordinator, client, _, _, _) = makeCoordinator(state())
    await client.setFailPatch(true)
    await coordinator.dismissCard()
    #expect(coordinator.isCardVisible)
    #expect(coordinator.inlineMessage == GuidedStartCopy.dismissFailed)
  }

  @Test("A dismissal from another device waits for the open step")
  func dismissalElsewhereWaitsForOpenStep() async {
    let (coordinator, _, store, _, _) = makeCoordinator(state())
    await coordinator.start(.addHolding)
    store.apply(state(dismissed: true))
    #expect(coordinator.isCardVisible, "an engaged step keeps the card")
    coordinator.skip()
    #expect(coordinator.isCardVisible == false)
  }

  @Test("Show me around on a finished wizard shows the completed card this session")
  func showMeAround() async {
    let (coordinator, _, _, analytics, _) = makeCoordinator(state(holding: true, budget: true, goal: true, dismissed: true))
    await coordinator.showMeAround()
    #expect(coordinator.isCardVisible)
    #expect(analytics.names == ["guided_start_reopened"])
  }
}
