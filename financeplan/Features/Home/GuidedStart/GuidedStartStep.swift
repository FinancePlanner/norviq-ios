import Foundation
import StockPlanShared

/// A place in the UI the spotlight can frame. A target is not a step: the
/// goal step passes through two.
nonisolated enum GuidedTarget: String, Sendable, CaseIterable {
  case holdingAdd = "holding-add"
  case budgetSalary = "budget-salary"
  case goalCard = "goal-card"
  case goalCreate = "goal-create"
}

/// Where an anchor lives. `goalPlanning` is the full-screen cover, which has
/// its own overlay because anchors do not cross a presentation.
enum GuidedTab: String, Sendable {
  case dashboard
  case portfolio
  case expenses
  case goalPlanning
}

nonisolated enum GuidedStartStep: String, CaseIterable, Identifiable, Sendable {
  case addHolding = "add_holding"
  case setBudget = "set_budget"
  case setGoal = "set_goal"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .addHolding: String(localized: "Add a holding")
    case .setBudget: String(localized: "Set your budget")
    case .setGoal: String(localized: "Set a goal")
    }
  }

  var line: String {
    switch self {
    case .addHolding: String(localized: "Add one stock or ETF you own.")
    case .setBudget: String(localized: "Enter your monthly take-home pay.")
    case .setGoal: String(localized: "Pick one thing you're saving for.")
    }
  }

  /// First the place the step starts, then anything it leads into.
  var targets: [GuidedTarget] {
    switch self {
    case .addHolding: [.holdingAdd]
    case .setBudget: [.budgetSalary]
    case .setGoal: [.goalCard, .goalCreate]
    }
  }

  /// The tab the step starts on.
  var tab: GuidedTab {
    switch self {
    case .addHolding: .portfolio
    case .setBudget: .expenses
    case .setGoal: .dashboard
    }
  }

  func isComplete(in state: OnboardingStateDTO) -> Bool {
    switch self {
    case .addHolding: state.addHoldingCompleted
    case .setBudget: state.setBudgetCompleted
    case .setGoal: state.setGoalCompleted
    }
  }
}

struct GuidedStartProgress: Equatable, Sendable {
  let completed: Set<GuidedStartStep>
  let next: GuidedStartStep?

  var isAllDone: Bool { next == nil }
  var completedCount: Int { completed.count }

  init(_ state: OnboardingStateDTO?) {
    guard let state else {
      completed = []
      next = GuidedStartStep.allCases.first
      return
    }
    completed = Set(GuidedStartStep.allCases.filter { $0.isComplete(in: state) })
    next = GuidedStartStep.allCases.first { !$0.isComplete(in: state) }
  }
}

enum GuidedStartCopy {
  static let headline = String(localized: "Get started with Norviq")
  static let skip = String(localized: "Skip")
  static let completion = String(localized: "You're set up. Everything else builds on these three.")
  static let dismissFailed = String(localized: "Couldn't hide that just now — try again in a moment.")
  static let reopenFailed = String(localized: "Here for now — I couldn't save that, so this may hide again next time.")

  static func progress(completed: Int) -> String {
    "\(completed) of \(GuidedStartStep.allCases.count)"
  }
}
