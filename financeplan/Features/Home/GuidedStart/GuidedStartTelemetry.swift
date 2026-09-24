import Foundation
import PostHog

enum GuidedStartEvent {
  static let cardShown = "guided_start_card_shown"
  static let stepStarted = "guided_start_step_started"
  static let stepCompleted = "guided_start_step_completed"
  static let stepSkipped = "guided_start_step_skipped"
  static let stepTimedOut = "guided_start_step_timed_out"
  static let dismissed = "guided_start_dismissed"
  static let reopened = "guided_start_reopened"
  static let completed = "guided_start_completed"
}

enum GuidedStartSource: String, Sendable {
  case auto
  case settings
}

@MainActor
protocol GuidedStartAnalytics: AnyObject {
  func capture(_ event: String, properties: [String: Any]?)
}

@MainActor
final class PostHogGuidedStartAnalytics: GuidedStartAnalytics {
  func capture(_ event: String, properties: [String: Any]?) {
    PostHogSDK.shared.capture(event, properties: properties)
  }
}

@MainActor
struct GuidedStartTelemetry {
  private let analytics: any GuidedStartAnalytics

  init(analytics: any GuidedStartAnalytics = PostHogGuidedStartAnalytics()) {
    self.analytics = analytics
  }

  func cardShown() { analytics.capture(GuidedStartEvent.cardShown, properties: nil) }
  func dismissed() { analytics.capture(GuidedStartEvent.dismissed, properties: nil) }
  func reopened() { analytics.capture(GuidedStartEvent.reopened, properties: nil) }
  func completed() { analytics.capture(GuidedStartEvent.completed, properties: nil) }

  func stepStarted(_ step: GuidedStartStep, source: GuidedStartSource) {
    analytics.capture(GuidedStartEvent.stepStarted, properties: ["step": step.rawValue, "source": source.rawValue])
  }

  func stepCompleted(_ step: GuidedStartStep, elapsedMs: Int, completedElsewhere: Bool) {
    analytics.capture(GuidedStartEvent.stepCompleted, properties: [
      "step": step.rawValue, "elapsed_ms": elapsedMs, "completed_elsewhere": completedElsewhere,
    ])
  }

  func stepSkipped(_ step: GuidedStartStep, elapsedMs: Int) {
    analytics.capture(GuidedStartEvent.stepSkipped, properties: ["step": step.rawValue, "elapsed_ms": elapsedMs])
  }

  func stepTimedOut(_ step: GuidedStartStep, elapsedMs: Int) {
    analytics.capture(GuidedStartEvent.stepTimedOut, properties: ["step": step.rawValue, "elapsed_ms": elapsedMs])
  }
}
