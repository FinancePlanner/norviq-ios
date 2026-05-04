import Foundation
import Observation
import OSLog
import StockPlanShared
import Factory

private let homePerformanceLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
  category: "HomePerformance"
)

@MainActor
@Observable
final class FocusPointsViewModel {
    var points: [GoalResponse] = []
    var draftTitle = ""
    var isLoading = false
    var isSubmitting = false
    var pendingStatusUpdates: Set<String> = []
    var errorMessage: String?

    @ObservationIgnored
    @Injected(\.goalsService) private var goalsService

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            points = try await goalsService.getGoals()
        } catch {
            homePerformanceLogger.error("Focus points load failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    func createFromDraft() async {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !isSubmitting else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let created = try await goalsService.createGoal(payload: GoalRequest(title: title))
            points.insert(created, at: 0)
            draftTitle = ""
        } catch {
            homePerformanceLogger.error("Focus point create failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    func toggleStatus(for point: GoalResponse) async {
        guard !pendingStatusUpdates.contains(point.id) else { return }
        pendingStatusUpdates.insert(point.id)
        errorMessage = nil
        defer { pendingStatusUpdates.remove(point.id) }

        let nextStatus: GoalStatus = point.status == .completed ? .pending : .completed
        do {
            let updated = try await goalsService.updateGoalStatus(
                id: point.id,
                payload: GoalStatusUpdateRequest(status: nextStatus, source: .manual)
            )

            guard let index = points.firstIndex(where: { $0.id == updated.id }) else { return }
            points[index] = updated
        } catch {
            homePerformanceLogger.error("Focus point status update failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }
}
