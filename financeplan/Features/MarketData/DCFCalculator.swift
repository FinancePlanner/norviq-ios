import Foundation

enum DCFCalculator {
  /// Calculates the Discounted Cash Flow (DCF) fair value per share.
  ///
  /// - Parameters:
  ///   - yearlyProjections: The explicit period yearly projections containing the free cash flow (FCF).
  ///   - wacc: Weighted Average Cost of Capital (Discount Rate).
  ///   - terminalGrowth: Terminal growth rate (Gordon Growth Model).
  ///   - netDebt: Total debt minus cash and equivalents.
  ///   - shares: Shares outstanding.
  /// - Returns: The intrinsic fair value per share based on DCF.
  static func calculateDCF(
    yearlyProjections: [YearlyProjection],
    wacc: Double,
    terminalGrowth: Double,
    netDebt: Double,
    shares: Double
  ) -> Double {
    var pvExplicit: Double = 0.0
    let numYears = yearlyProjections.count

    for (i, proj) in yearlyProjections.enumerated() {
      let year = Double(i + 1)
      let discountFactor = pow(1 + wacc, year)
      pvExplicit += (proj.fcf ?? 0) / discountFactor
    }

    let finalFCF = yearlyProjections.last?.fcf ?? 0
    let terminalValue = finalFCF * (1 + terminalGrowth) / (wacc - terminalGrowth)
    let pvTerminal = terminalValue / pow(1 + wacc, Double(numYears))

    let equityValue = pvExplicit + pvTerminal - netDebt
    return equityValue / shares
  }
}
