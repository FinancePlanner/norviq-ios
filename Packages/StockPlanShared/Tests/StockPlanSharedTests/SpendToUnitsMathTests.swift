import Foundation
import Testing
@testable import StockPlanShared

@Suite("Spend-to-units math")
struct SpendToUnitsMathTests {
    @Test("Units divide leftover cash by last price")
    func unitsFromPrice() {
        #expect(SpendToUnitsMath.units(amount: 240, price: 132.10) == 1.82)
        #expect(SpendToUnitsMath.units(amount: 80, price: 132.10) == 0.61)
        #expect(SpendToUnitsMath.units(amount: 80, price: 0) == nil)
        #expect(SpendToUnitsMath.units(amount: 80, price: nil) == nil)
    }

    @Test("Surplus prefers leftover investment capacity when a DCA target exists")
    func surplusUsesInvestmentTarget() {
        let ready = SpendToUnitsMath.surplus(
            investmentContributionTarget: 500,
            lostInvestmentCapital: 180,
            totalTarget: 2000,
            totalActual: 1900
        )
        #expect(ready == 320)
    }

    @Test("Surplus falls back to leftover budget when there is no investment target")
    func surplusFallsBackToBudgetLeftover() {
        let leftover = SpendToUnitsMath.surplus(
            investmentContributionTarget: 0,
            lostInvestmentCapital: 0,
            totalTarget: 2000,
            totalActual: 1760
        )
        #expect(leftover == 240)
    }

    @Test("Symbol normalizer uppercases and rejects junk")
    func normalizeSymbol() {
        #expect(SpendToUnitsMath.normalizeSymbol(" vwce ") == "VWCE")
        #expect(SpendToUnitsMath.normalizeSymbol("IWDA.AS") == "IWDA.AS")
        #expect(SpendToUnitsMath.normalizeSymbol("") == nil)
        #expect(SpendToUnitsMath.normalizeSymbol("THIS_IS_WAY_TOO_LONG") == nil)
        #expect(SpendToUnitsMath.normalizeSymbol("VWCE!") == nil)
    }
}
