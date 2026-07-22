import StockPlanShared
import Testing

@testable import financeplan

@MainActor
struct PersonalInflationViewModelTests {
  @Test func loadsPersonalInflation() async {
    let expected = makeResponse(rate: 3.4, official: 2.8)
    let viewModel = PersonalInflationViewModel { country, months in
      #expect(country == "PT")
      #expect(months == 6)
      return expected
    }

    await viewModel.load(country: "PT", months: 6)

    #expect(viewModel.response == expected)
    #expect(viewModel.errorMessage == nil)
    #expect(!viewModel.isLoading)
  }

  @Test func describesComparisonWithOfficialRate() {
    let response = makeResponse(rate: 3.4, official: 2.8)
    #expect(PersonalInflationViewModel.comparisonText(for: response)?.contains("above") == true)
  }

  private func makeResponse(rate: Double, official: Double) -> PersonalInflationResponse {
    PersonalInflationResponse(
      country: "PT",
      currency: "EUR",
      asOf: "2026-06-01",
      periodMonths: 6,
      sampleStart: "2026-01-01",
      sampleEnd: "2026-07-01",
      personalRate: rate,
      officialRate: official,
      difference: rate - official,
      averageMonthlySpend: 1_500,
      estimatedAnnualImpact: 612,
      coveragePercent: 80,
      mappedSpend: 7_200,
      totalSpend: 9_000,
      expenseCount: 40,
      method: "expense_weighted_cpi_v1",
      source: "User expenses + Eurostat",
      components: []
    )
  }
}
