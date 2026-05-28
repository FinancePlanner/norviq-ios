//
//  OnboardingImportFlow.swift
//  financeplan
//
//  Created by Fernando Correia on 27.02.26.
//
import StockPlanShared
import SwiftUI

struct OnboardingImportFlow: View {
  @StateObject private var viewModel = OnboardingImportViewModel()
  @Namespace private var headerNS
  let onFinished: () -> Void
  let onSignOut: () async -> Void

  var body: some View {
    Group {
      switch viewModel.step {
      case .mainMenu:
        OnboardingMainMenu(
          onSelectStocks: { viewModel.startStockImport() },
          onSelectExpenses: { viewModel.startExpenseImport() },
          onSignOut: {
            Task { await onSignOut() }
          },
          onSkip: onFinished
        )
      case .chooseStockMethod:
        InitialStockImportScreen(
          onImportCompleted: { method in viewModel.selectStockMethod(method) },
          onSignOut: {
            Task { await onSignOut() }
          },
          onBack: { viewModel.backToMain() },
          headerNamespace: headerNS
        )
      case .csv:
        CSVImportScreen(
          headerNamespace: headerNS,
          onBack: { viewModel.backToChooseStock() },
          onDone: { _ in viewModel.finish(completedFlow: .stocks) }
        )
      case .manual:
        ManualImportScreen(
          headerNamespace: headerNS,
          onBack: { viewModel.backToChooseStock() },
          onDone: { _ in viewModel.finish(completedFlow: .stocks) }
        )
      case .expenseBudgetSetup:
        ExpenseBudgetSetupScreen(
          headerNamespace: headerNS,
          onBack: { viewModel.backToMain() },
          onDone: { viewModel.finish(completedFlow: .expenses) }
        )
      case .success:
        SuccessImportScreen(
          optionalNextActionTitle: viewModel.optionalNextAction?.title,
          onOptionalNextAction: { viewModel.startOptionalNextAction() },
          onDone: { viewModel.complete() }
        )
      case .done:
        Color.clear.onAppear(perform: onFinished)
      }
    }
    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.step)
  }
}
