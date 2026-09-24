import Foundation
import Observation
import StockPlanShared

/// Drives the "Get started with Norviq" card and its steps. Completion is the
/// server's word: a step finishes when its latch flips on a poll, never when
/// the client thinks it saved. Contract: norviq-shared/docs/guided-start.md.
@MainActor
@Observable
final class GuidedStartCoordinator {
  enum Phase: Equatable {
    case idle
    case active(GuidedStartStep, startedAt: Date)
    case celebrating(GuidedStartStep)
    case finished

    /// The card stays while any of these hold, even if a dismissal arrives
    /// from another device mid-step. `.finished` is not engaged: once the
    /// wizard has landed there, a dismissal — local or from another device —
    /// applies normally, same as the completed card in any other state.
    var isEngaged: Bool {
      switch self {
      case .active, .celebrating: return true
      case .idle, .finished: return false
      }
    }
  }

  /// 1s, 2s, 4s, 8s, then every 10s, giving up after 5 minutes.
  private static let pollBackoff: [Duration] = [.seconds(1), .seconds(2), .seconds(4), .seconds(8)]
  private static let pollSteadyState: Duration = .seconds(10)
  static let stepTimeout: TimeInterval = 300
  private static let celebrationDwell: Duration = .milliseconds(1_600)

  private(set) var phase: Phase = .idle
  private(set) var inlineMessage: String?
  private(set) var requestedTab: GuidedTab?
  private var dismissOverride: Bool?
  private var sessionShowsCompletedCard = false

  @ObservationIgnored private let client: any OnboardingClientProtocol
  @ObservationIgnored private let telemetry: GuidedStartTelemetry
  @ObservationIgnored private let now: @MainActor () -> Date
  @ObservationIgnored private let sleep: @MainActor (Duration) async throws -> Void
  @ObservationIgnored private let snapshot: @MainActor () -> OnboardingStateDTO?
  @ObservationIgnored private let applySnapshot: @MainActor (OnboardingStateDTO) -> Void

  @ObservationIgnored private var pendingSource: GuidedStartSource?
  @ObservationIgnored private var didFireCardShown = false
  @ObservationIgnored private var locallyActed: Set<GuidedStartStep> = []
  @ObservationIgnored private var work: Task<Void, Never>?
  @ObservationIgnored private var workGeneration = 0
  @ObservationIgnored private var runID = 0
  @ObservationIgnored private var pollIndex = 0

  init(
    client: any OnboardingClientProtocol,
    telemetry: GuidedStartTelemetry,
    now: @MainActor @escaping () -> Date = { Date() },
    sleep: @MainActor @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
    snapshot: @MainActor @escaping () -> OnboardingStateDTO?,
    applySnapshot: @MainActor @escaping (OnboardingStateDTO) -> Void
  ) {
    self.client = client
    self.telemetry = telemetry
    self.now = now
    self.sleep = sleep
    self.snapshot = snapshot
    self.applySnapshot = applySnapshot
  }

  // MARK: - Derived state

  var progress: GuidedStartProgress { GuidedStartProgress(snapshot()) }

  var activeStep: GuidedStartStep? {
    if case .active(let step, _) = phase { return step }
    return nil
  }

  var isDismissed: Bool { dismissOverride ?? (snapshot()?.guidedStartDismissedAt != nil) }

  var isCardVisible: Bool {
    guard let state = snapshot(), state.funnelCompletedAt != nil else { return false }
    if phase.isEngaged { return true }
    if isDismissed { return false }
    if progress.isAllDone { return sessionShowsCompletedCard }
    return true
  }

  // MARK: - Card lifecycle

  func noteCardShown() {
    guard isCardVisible, !didFireCardShown else { return }
    didFireCardShown = true
    telemetry.cardShown()
  }

  func refresh() async {
    guard let state = try? await client.get() else { return }
    applySnapshot(state)
  }

  // MARK: - Steps

  func start(_ step: GuidedStartStep, source: GuidedStartSource = .auto) async {
    inlineMessage = nil
    cancelWork()
    await refresh()
    cancelWork()

    guard let target = resolveStart(step) else {
      finishWizard()
      return
    }

    let startedAt = now()
    locallyActed.remove(target)
    pollIndex = 0
    runID += 1
    let run = runID

    phase = .active(target, startedAt: startedAt)
    requestedTab = target.tab
    telemetry.stepStarted(target, source: pendingSource ?? source)
    pendingSource = nil

    startPolling(target, startedAt: startedAt, run: run, delayIndex: 0, pollImmediately: false)
  }

  /// Skip closes this step; the card stays.
  func skip() {
    guard case .active(let step, let startedAt) = phase else { return }
    cancelWork()
    runID += 1
    telemetry.stepSkipped(step, elapsedMs: elapsedMs(since: startedAt))
    closeStep()
  }

  /// The user did the step's action here. Poll now instead of on the next tick.
  func noteUserAction(_ step: GuidedStartStep) {
    locallyActed.insert(step)
    guard case .active(let current, let startedAt) = phase, current == step else { return }
    let resumeIndex = pollIndex
    cancelWork()
    runID += 1
    startPolling(step, startedAt: startedAt, run: runID, delayIndex: resumeIndex, pollImmediately: true)
  }

  // MARK: - Dismissal

  func dismissCard() async {
    dismissOverride = true
    inlineMessage = nil
    telemetry.dismissed()
    do {
      applySnapshot(try await client.patch(OnboardingPatchRequest(guidedStartDismissed: true)))
    } catch {
      dismissOverride = nil
      inlineMessage = GuidedStartCopy.dismissFailed
    }
  }

  func showMeAround() async {
    dismissOverride = false
    inlineMessage = nil
    pendingSource = .settings
    if progress.isAllDone { sessionShowsCompletedCard = true }
    telemetry.reopened()
    do {
      applySnapshot(try await client.patch(OnboardingPatchRequest(guidedStartDismissed: false)))
    } catch {
      inlineMessage = GuidedStartCopy.reopenFailed
    }
  }

  // MARK: - Polling

  private enum Tick { case keepGoing, stop }

  private func startPolling(_ step: GuidedStartStep, startedAt: Date, run: Int, delayIndex: Int, pollImmediately: Bool) {
    let sleep = self.sleep
    let backoff = Self.pollBackoff
    let steady = Self.pollSteadyState

    workGeneration += 1
    work = Task { [weak self] in
      var index = delayIndex
      var immediate = pollImmediately
      while true {
        if Task.isCancelled { return }
        if immediate {
          immediate = false
        } else {
          let delay = index < backoff.count ? backoff[index] : steady
          index += 1
          self?.pollIndex = index
          do { try await sleep(delay) } catch { return }
        }
        guard let tick = await self?.pollTick(step, startedAt: startedAt, run: run) else { return }
        if tick == .stop { return }
      }
    }
  }

  private func pollTick(_ step: GuidedStartStep, startedAt: Date, run: Int) async -> Tick {
    guard isRunning(step, run: run) else { return .stop }
    if let state = try? await client.get() {
      guard isRunning(step, run: run) else { return .stop }
      applySnapshot(state)
      if step.isComplete(in: state) {
        await complete(step, startedAt: startedAt)
        return .stop
      }
    }
    guard isRunning(step, run: run) else { return .stop }
    if now().timeIntervalSince(startedAt) >= Self.stepTimeout {
      telemetry.stepTimedOut(step, elapsedMs: elapsedMs(since: startedAt))
      closeStep()
      return .stop
    }
    return .keepGoing
  }

  private func complete(_ step: GuidedStartStep, startedAt: Date) async {
    telemetry.stepCompleted(step, elapsedMs: elapsedMs(since: startedAt), completedElsewhere: !locallyActed.contains(step))
    locallyActed.remove(step)
    requestedTab = nil
    phase = .celebrating(step)
    let allDone = progress.isAllDone
    try? await sleep(Self.celebrationDwell)
    guard case .celebrating(let current) = phase, current == step else { return }
    if allDone {
      sessionShowsCompletedCard = true
      phase = .finished
      telemetry.completed()
    } else {
      phase = .idle
    }
  }

  // MARK: - Helpers

  private func resolveStart(_ step: GuidedStartStep) -> GuidedStartStep? {
    guard let state = snapshot() else { return step }
    if !step.isComplete(in: state) { return step }
    return progress.next
  }

  private func finishWizard() {
    guard phase != .finished else { return }
    requestedTab = nil
    sessionShowsCompletedCard = true
    phase = .finished
    telemetry.completed()
  }

  private func closeStep() {
    requestedTab = nil
    inlineMessage = nil
    phase = .idle
  }

  private func isRunning(_ step: GuidedStartStep, run: Int) -> Bool {
    guard !Task.isCancelled, run == runID else { return false }
    guard case .active(let current, _) = phase, current == step else { return false }
    return true
  }

  private func elapsedMs(since startedAt: Date) -> Int {
    Int((now().timeIntervalSince(startedAt) * 1_000).rounded())
  }

  private func cancelWork() {
    work?.cancel()
    work = nil
  }

  #if DEBUG
  /// Waits for polling to finish, including work that replaced itself.
  func settle() async {
    for _ in 0..<64 {
      guard let task = work else { return }
      let generation = workGeneration
      await task.value
      if workGeneration == generation {
        work = nil
        return
      }
    }
  }
  #endif
}
