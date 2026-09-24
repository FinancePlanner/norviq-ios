import Foundation
import StockPlanShared

/// A standing task ("watch X and ping me when Y") the assistant offers to set
/// up. It rides on a `create_watch` pending action; confirming or cancelling
/// that action is what creates or drops the task.
nonisolated struct MuseStandingTask: Equatable, Sendable {
    static let toolName = "create_watch"

    let actionID: String
    let title: String
    /// e.g. "Every day at 8:00".
    let scheduleHuman: String
    /// What the assistant checks on each run.
    let spec: String

    /// Prefers the turn's `watchProposal`; after a reload only the action is
    /// left (`GET /v1/ai/assistant/actions`), so its `arguments` JSON redraws
    /// the card. Nil for any other action, or arguments that do not describe
    /// a watch, so those fall back to the generic confirmation card.
    static func from(_ action: AIPendingActionResponse, proposal: AIWatchProposalResponse? = nil) -> MuseStandingTask? {
        guard action.toolName == toolName else { return nil }
        if let proposal {
            return MuseStandingTask(
                actionID: action.id, title: proposal.title,
                scheduleHuman: proposal.scheduleHuman, spec: proposal.spec
            )
        }
        guard let arguments = try? JSONDecoder().decode(Arguments.self, from: Data(action.arguments.utf8)),
              !arguments.title.isEmpty
        else { return nil }
        return MuseStandingTask(
            actionID: action.id, title: arguments.title,
            scheduleHuman: arguments.scheduleHuman, spec: arguments.spec
        )
    }

    /// The subset of the server's `WatchArguments` the card needs.
    private struct Arguments: Decodable {
        let title: String
        let scheduleHuman: String
        let spec: String
    }
}

/// What happened when the user answered a standing-task card.
nonisolated enum MuseStandingTaskOutcome: Equatable, Sendable {
    /// The server said the action was no longer pending (409): a second
    /// confirm, or one from another device.
    case alreadySetUp
}

/// The caption above a proactive agent bubble ("Standing task", "Daily tip").
nonisolated enum MuseMessageCaption {
    static func text(for message: AIMessageResponse) -> String? {
        guard message.role == .assistant, message.origin == .proactive else { return nil }
        let label = message.sourceLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return label.isEmpty ? "From Vig" : label
    }
}
