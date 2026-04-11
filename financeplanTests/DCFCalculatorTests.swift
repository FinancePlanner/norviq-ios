import XCTest
@testable import financeplan

@MainActor
final class DCFCalculatorTests: XCTestCase {

  @MainActor
  func testCalculateDCF_WithValidInputs_ComputesFairValuePerShare() {
    let projections = [
      YearlyProjection(year: 2025, revenue: 110, revenueGrowth: 0.1, netIncome: 20, netIncomeGrowth: 0.1, netMargin: 0.18, eps: 2.0, fcf: 25.0, fcfMargin: 0.22),
      YearlyProjection(year: 2026, revenue: 121, revenueGrowth: 0.1, netIncome: 22, netIncomeGrowth: 0.1, netMargin: 0.18, eps: 2.2, fcf: 30.0, fcfMargin: 0.24),
      YearlyProjection(year: 2027, revenue: 133, revenueGrowth: 0.1, netIncome: 24, netIncomeGrowth: 0.1, netMargin: 0.18, eps: 2.4, fcf: 35.0, fcfMargin: 0.26)
    ]

    let wacc = 0.10
    let terminalGrowth = 0.03
    let netDebt: Double = 50.0
    let shares: Double = 10.0

    let fairValue = DCFCalculator.calculateDCF(
      yearlyProjections: projections,
      wacc: wacc,
      terminalGrowth: terminalGrowth,
      netDebt: netDebt,
      shares: shares
    )

    // Manual Calculation:
    // PV of FCF 1: 25 / (1.1)^1 = 22.727
    // PV of FCF 2: 30 / (1.1)^2 = 24.793
    // PV of FCF 3: 35 / (1.1)^3 = 26.296
    // PV Explicit = 22.727 + 24.793 + 26.296 = 73.816

    // TV = 35 * (1 + 0.03) / (0.10 - 0.03) = 36.05 / 0.07 = 515.0
    // PV Terminal = 515.0 / (1.1)^3 = 515.0 / 1.331 = 386.927

    // Equity Value = 73.816 + 386.927 - 50 = 410.743
    // Fair Value = 410.743 / 10 = 41.0743

    XCTAssertEqual(fairValue, 41.0743, accuracy: 0.001)
  }

  @MainActor
  func testCalculateDCF_WithZeroFCF_ComputesValidResult() {
    let projections = [
      YearlyProjection(year: 2025, revenue: 110, revenueGrowth: 0.1, netIncome: 20, netIncomeGrowth: 0.1, netMargin: 0.18, eps: 2.0, fcf: nil, fcfMargin: nil)
    ]

    let fairValue = DCFCalculator.calculateDCF(
      yearlyProjections: projections,
      wacc: 0.10,
      terminalGrowth: 0.02,
      netDebt: 0,
      shares: 10
    )

    XCTAssertEqual(fairValue, 0.0, accuracy: 0.001)
  }

  @MainActor
  func testCalculateDCF_WithHighDebt_ComputesNegativeOrLowValue() {
    let projections = [
      YearlyProjection(year: 2025, revenue: 110, revenueGrowth: 0.1, netIncome: 20, netIncomeGrowth: 0.1, netMargin: 0.18, eps: 2.0, fcf: 10.0, fcfMargin: 0.1)
    ]

    let wacc = 0.10
    let terminalGrowth = 0.02
    let netDebt: Double = 1000.0 // Very high debt
    let shares: Double = 10.0

    let fairValue = DCFCalculator.calculateDCF(
      yearlyProjections: projections,
      wacc: wacc,
      terminalGrowth: terminalGrowth,
      netDebt: netDebt,
      shares: shares
    )

    // TV = 10 * 1.02 / 0.08 = 127.5
    // PV = 10 / 1.1 + 127.5 / 1.1 = 9.09 + 115.91 = 125
    // Eq = 125 - 1000 = -875
    // per share = -87.5

    XCTAssertEqual(fairValue, -87.5, accuracy: 0.1)
  }
}
