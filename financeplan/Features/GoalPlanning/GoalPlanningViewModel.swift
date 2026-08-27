import Factory
import Foundation
import Observation
import StockPlanShared

@MainActor @Observable
final class GoalPlanningViewModel {
  private(set) var overview: GoalOverview?
  private(set) var templates: [GoalTemplate] = []
  private(set) var portfolios: [PortfolioListDTOResponse] = []
  private(set) var progressByGoal: [String: GoalProgress] = [:]
  private(set) var suggestionsByGoal: [String: [GoalSuggestion]] = [:]
  var isLoading = false
  var isSaving = false
  var errorMessage: String?
  var confirmationMessage: String?

  private let service: any GoalPlanningServicing

  init(service: any GoalPlanningServicing) {
    self.service = service
  }

  var canCreateActiveGoal: Bool {
    guard let overview else { return true }
    return overview.isPro || overview.activeGoalLimit.map { overview.activeGoalCount < $0 } ?? true
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      async let overviewRequest = service.overview()
      async let templateRequest = service.templates()
      async let portfolioRequest = service.portfolios()
      overview = try await overviewRequest
      templates = try await templateRequest
      portfolios = try await portfolioRequest
      await considerGoalCompletionReview()
    } catch {
      errorMessage = "Goal planning is temporarily unavailable."
    }
  }

  /// Reaching a savings or investment target is the single strongest moment this app
  /// has. Each goal is keyed separately, so a second goal can still earn its own prompt
  /// once the cooldown has passed.
  private func considerGoalCompletionReview() async {
    guard let completed = overview?.items.first(where: { $0.progress.percentComplete >= 1 })
    else { return }
    let userID = await Container.shared.authSessionStore().currentUserID
    guard !userID.isEmpty else { return }
    Container.shared.reviewPromptCoordinator()
      .consider(.goalCompleted(goalID: completed.id), userID: userID)
  }

  func loadDetails(goalId: String) async {
    do {
      async let progressRequest = service.progress(goalId: goalId)
      async let suggestionRequest = service.suggestions(goalId: goalId)
      progressByGoal[goalId] = try await progressRequest
      suggestionsByGoal[goalId] = try await suggestionRequest
    } catch {
      errorMessage = "This goal could not be refreshed."
    }
  }

  func create(_ input: FinancialGoalInput) async -> Bool {
    isSaving = true
    defer { isSaving = false }
    do {
      _ = try await service.create(input)
      await load()
      return true
    } catch {
      errorMessage = "The financial goal could not be created. Check the portfolio allocation and try again."
      return false
    }
  }

  func runWhatIf(goalId: String, contribution: Double, annualReturn: Double) async {
    do {
      let response = try await service.whatIf(
        goalId: goalId,
        request: .init(monthlyContribution: contribution, expectedAnnualReturn: annualReturn)
      )
      progressByGoal[goalId] = response.scenario
    } catch {
      errorMessage = "The scenario could not be calculated."
    }
  }

  func accept(_ suggestion: GoalSuggestion) async {
    do {
      let draft = try await service.accept(goalId: suggestion.goalId, suggestionId: suggestion.id)
      confirmationMessage = "A \(draft.destination.rawValue) draft is ready for review. No changes were applied."
      await loadDetails(goalId: suggestion.goalId)
    } catch {
      errorMessage = "The adjustment draft could not be prepared. Pro may be required for linked budget or rebalance changes."
    }
  }

  func addContribution(goalId: String, amount: Double, date: Date) async -> Bool {
    do {
      _ = try await service.addContribution(
        goalId: goalId,
        input: .init(amount: amount, occurredAt: Self.dayFormatter.string(from: date))
      )
      await loadDetails(goalId: goalId)
      return true
    } catch {
      errorMessage = "The contribution could not be recorded."
      return false
    }
  }

  private static let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()
}
