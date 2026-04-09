import Combine
import SwiftUI

@MainActor
final class OnboardingImportViewModel: ObservableObject {
  enum CompletedFlow {
    case stocks
    case expenses
  }

  enum OptionalNextAction {
    case setUpExpenses
    case setUpStocks

    var title: String {
      switch self {
      case .setUpExpenses:
        return "Set up expenses next"
      case .setUpStocks:
        return "Set up stocks next"
      }
    }
  }

  enum Step: Hashable {
    case mainMenu
    case chooseStockMethod
    case csv
    case manual
    case api
    case expenseBudgetSetup
    case success
    case done
  }

  @Published var step: Step = .mainMenu
  private var hasCompletedStocksSetup = false
  private var hasCompletedExpensesSetup = false

  func startStockImport() {
    step = .chooseStockMethod
  }

  func startExpenseImport() {
    step = .expenseBudgetSetup
  }

  func selectStockMethod(_ method: StockImportMethod) {
    switch method {
    case .csv:
      step = .csv
    case .manual:
      step = .manual
    case .api:
      step = .api
    }
  }

  func backToMain() { step = .mainMenu }
  func backToChooseStock() { step = .chooseStockMethod }
  func finish(completedFlow: CompletedFlow) {
    switch completedFlow {
    case .stocks:
      hasCompletedStocksSetup = true
    case .expenses:
      hasCompletedExpensesSetup = true
    }
    step = .success
  }

  var optionalNextAction: OptionalNextAction? {
    if hasCompletedStocksSetup && !hasCompletedExpensesSetup {
      return .setUpExpenses
    }
    if hasCompletedExpensesSetup && !hasCompletedStocksSetup {
      return .setUpStocks
    }
    return nil
  }

  func startOptionalNextAction() {
    switch optionalNextAction {
    case .setUpExpenses:
      step = .expenseBudgetSetup
    case .setUpStocks:
      step = .chooseStockMethod
    case .none:
      break
    }
  }

  func complete() { step = .done }
}
