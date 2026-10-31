import Foundation
import Testing
@testable import StockPlanShared

struct RetirementPlanningDTOsTests {
    @Test(arguments: TaxJurisdiction.allCases)
    func `retirement plans support every tax jurisdiction`(_ jurisdiction: TaxJurisdiction) throws {
        let input = makeInput(jurisdiction: jurisdiction)
        let data = try JSONEncoder().encode(input)
        let decoded = try JSONDecoder().decode(RetirementPlanInput.self, from: data)

        #expect(decoded == input)
        #expect(decoded.jurisdiction == jurisdiction)
    }

    @Test
    func `retirement plan preserves employer match pension and withdrawal choices`() throws {
        let input = makeInput(jurisdiction: .portugal)
        let plan = RetirementPlan(
            id: "plan-1",
            portfolioId: "portfolio-1",
            ruleVersion: "PT-2026.1",
            input: input,
            newerRuleVersion: "PT-2027.1",
            createdAt: "2026-07-14T08:00:00Z"
        )

        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(RetirementPlan.self, from: data)

        #expect(decoded == plan)
        #expect(decoded.input.accounts.first?.employerMatch?.matchRate == 0.5)
        #expect(decoded.input.publicPension?.startAge == 67)
        #expect(decoded.input.withdrawalStrategy == .guardrails)
    }

    @Test
    func `effective dated rule pack round trips source metadata`() throws {
        let rule = RetirementWrapperRule(
            wrapper: .portugalPPR,
            maximumEmployeeAnnualContribution: 2000,
            minimumWithdrawalAge: 60,
            earlyWithdrawalPenaltyRate: 0.1,
            contributionTaxDeductible: true,
            withdrawalsTaxable: true,
            notes: ["Illustrative fixture"]
        )
        let pack = RetirementRulePack(
            jurisdiction: .portugal,
            version: "PT-2026.1",
            effectiveFrom: "2026-01-01",
            currency: "EUR",
            wrappers: [rule],
            sources: [
                .init(
                    title: "Portuguese tax authority",
                    url: "https://info.portaldasfinancas.gov.pt/",
                    reviewedAt: "2026-07-14"
                ),
            ],
            disclaimer: "Planning estimate only."
        )

        let data = try JSONEncoder().encode(pack)
        #expect(try JSONDecoder().decode(RetirementRulePack.self, from: data) == pack)
    }

    @Test
    func `projection carries accumulation and retirement phases`() throws {
        let summary = RetirementProjectionSummary(
            readinessProbability: 0.81,
            sustainableAnnualSpending: 38000,
            projectedAnnualRetirementIncome: 42000,
            annualContributionHeadroom: 1200,
            shortfallAge: nil,
            medianValueAtRetirement: 720_000,
            medianValueAtLongevityAge: 210_000
        )
        let projection = RetirementProjection(
            id: "projection-1",
            portfolioId: "portfolio-1",
            ruleVersion: "PT-2026.1",
            currency: "EUR",
            summary: summary,
            points: [
                .init(
                    age: 45,
                    year: 2026,
                    phase: .accumulation,
                    p10: 80000,
                    p25: 90000,
                    p50: 100_000,
                    p75: 110_000,
                    p90: 120_000,
                    annualContribution: 12000,
                    annualWithdrawal: 0,
                    annualPensionIncome: 0
                ),
                .init(
                    age: 67,
                    year: 2048,
                    phase: .retirement,
                    p10: 450_000,
                    p25: 580_000,
                    p50: 720_000,
                    p75: 890_000,
                    p90: 1_050_000,
                    annualContribution: 0,
                    annualWithdrawal: 38000,
                    annualPensionIncome: 15000
                ),
            ],
            assumptions: ["2% inflation"],
            warnings: [],
            generatedAt: "2026-07-14T10:00:00Z"
        )

        let data = try JSONEncoder().encode(projection)
        #expect(try JSONDecoder().decode(RetirementProjection.self, from: data) == projection)
    }

    private func makeInput(jurisdiction: TaxJurisdiction) -> RetirementPlanInput {
        RetirementPlanInput(
            jurisdiction: jurisdiction,
            currency: jurisdiction == .unitedStates ? "USD" : "EUR",
            currentAge: 45,
            retirementAge: 67,
            longevityAge: 95,
            annualSalary: 80000,
            annualSalaryGrowthRate: 0.02,
            desiredAnnualSpending: 38000,
            inflationRate: 0.02,
            expectedAnnualReturn: 0.06,
            annualVolatility: 0.14,
            annualContributionGrowthRate: 0.02,
            withdrawalStrategy: .guardrails,
            withdrawalRate: 0.04,
            accounts: [
                .init(
                    id: "account-plan-1",
                    accountId: "account-1",
                    name: "Retirement account",
                    wrapper: jurisdiction == .unitedStates ? .us401k : .genericPension,
                    currentBalance: 100_000,
                    employeeAnnualContribution: 10000,
                    employerMatch: .init(matchRate: 0.5, upToSalaryPercent: 0.06),
                    annualFeeRate: 0.005
                ),
            ],
            publicPension: .init(
                annualAmount: 15000,
                startAge: 67,
                annualIndexationRate: 0.02,
                currency: jurisdiction == .unitedStates ? "USD" : "EUR"
            ),
            otherAnnualRetirementIncome: 2000
        )
    }
}
