import Foundation
import Observation
import StockPlanShared

@MainActor @Observable
final class RetirementPlanningViewModel {
  var jurisdiction = TaxJurisdiction.unitedStates
  var currentAge = 35
  var retirementAge = 67
  var longevityAge = 95
  var annualSalary = 80_000.0
  var desiredAnnualSpending = 50_000.0
  var currentBalance = 100_000.0
  var annualContribution = 12_000.0
  var publicPension = 0.0
  var expectedAnnualReturn = 0.05
  private(set) var plan: RetirementPlan?
  private(set) var rules: RetirementRulePack?
  private(set) var projection: RetirementProjection?
  private(set) var isLoading = false
  var errorMessage: String?

  private let portfolio: Portfolio
  private let service: any PortfolioReportingServicing

  init(portfolio: Portfolio, service: any PortfolioReportingServicing) {
    self.portfolio = portfolio
    self.service = service
  }

  func load() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      rules = try await service.retirementRules(jurisdiction: jurisdiction)
      do {
        let existing = try await service.retirementPlan(portfolioId: portfolio.id)
        apply(existing)
      } catch let error as StockHTTPClient.Error where error.statusCode == 404 {
        plan = nil
      }
      errorMessage = nil
    } catch is CancellationError {
      return
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func jurisdictionChanged() async {
    do {
      rules = try await service.retirementRules(jurisdiction: jurisdiction)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func saveAndProject() async {
    isLoading = true
    defer { isLoading = false }
    do {
      let saved = try await service.saveRetirementPlan(
        portfolioId: portfolio.id,
        request: RetirementPlanUpsertRequest(input: input, ruleVersion: plan?.ruleVersion)
      )
      plan = saved
      projection = try await service.projectRetirement(
        portfolioId: portfolio.id,
        request: RetirementProjectionRequest(ruleVersion: saved.ruleVersion)
      )
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func refreshRules() async {
    do {
      let refreshed = try await service.refreshRetirementRules(portfolioId: portfolio.id)
      plan = refreshed
      rules = try await service.retirementRules(jurisdiction: refreshed.input.jurisdiction)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private var input: RetirementPlanInput {
    RetirementPlanInput(
      jurisdiction: jurisdiction,
      currency: portfolio.baseCurrency,
      currentAge: currentAge,
      retirementAge: retirementAge,
      longevityAge: longevityAge,
      annualSalary: annualSalary,
      desiredAnnualSpending: desiredAnnualSpending,
      expectedAnnualReturn: expectedAnnualReturn,
      annualVolatility: 0.12,
      accounts: [
        RetirementAccountPlan(
          id: plan?.input.accounts.first?.id ?? UUID().uuidString,
          name: "Retirement savings",
          wrapper: plan?.input.accounts.first?.wrapper ?? .taxable,
          currentBalance: currentBalance,
          employeeAnnualContribution: annualContribution
        )
      ],
      publicPension: publicPension > 0
        ? RetirementPensionIncome(
          annualAmount: publicPension,
          startAge: retirementAge,
          currency: portfolio.baseCurrency
        )
        : nil
    )
  }

  private func apply(_ plan: RetirementPlan) {
    self.plan = plan
    jurisdiction = plan.input.jurisdiction
    currentAge = plan.input.currentAge
    retirementAge = plan.input.retirementAge
    longevityAge = plan.input.longevityAge
    annualSalary = plan.input.annualSalary
    desiredAnnualSpending = plan.input.desiredAnnualSpending
    expectedAnnualReturn = plan.input.expectedAnnualReturn
    currentBalance = plan.input.accounts.first?.currentBalance ?? 0
    annualContribution = plan.input.accounts.first?.employeeAnnualContribution ?? 0
    publicPension = plan.input.publicPension?.annualAmount ?? 0
  }
}
