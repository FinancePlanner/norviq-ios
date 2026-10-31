import Foundation
import Testing
@testable import StockPlanShared

@Test func personalInflationResponseRoundTripsJSON() throws {
    let response = PersonalInflationResponse(
        country: "US",
        currency: "USD",
        asOf: "2026-06-01",
        periodMonths: 12,
        sampleStart: "2025-07-01",
        sampleEnd: "2026-06-30",
        personalRate: 3.4,
        officialRate: 2.8,
        difference: 0.6,
        averageMonthlySpend: 2400,
        estimatedAnnualImpact: 979.2,
        coveragePercent: 82.5,
        mappedSpend: 23760,
        totalSpend: 28800,
        expenseCount: 132,
        method: "expense_weighted_cpi_v1",
        source: "User expenses + FRED/BLS",
        components: [
            PersonalInflationComponentDTO(
                category: "Groceries",
                macroCategory: "Food at Home",
                spend: 7200,
                weight: 30.3,
                inflationRate: 3.8,
                contribution: 1.15,
                expenseCount: 52
            ),
        ]
    )

    let data = try JSONEncoder().encode(response)
    let decoded = try JSONDecoder().decode(PersonalInflationResponse.self, from: data)

    #expect(decoded == response)
    #expect(decoded.components.first?.id == "Groceries")
}

@Test func personalInflationCanRepresentInsufficientMappedSpending() {
    let response = PersonalInflationResponse(
        country: "PT",
        currency: "EUR",
        asOf: "2026-06-01",
        periodMonths: 12,
        sampleStart: "2025-07-01",
        sampleEnd: "2026-06-30",
        officialRate: 2.1,
        averageMonthlySpend: 0,
        coveragePercent: 0,
        mappedSpend: 0,
        totalSpend: 0,
        expenseCount: 0,
        method: "expense_weighted_cpi_v1",
        source: "User expenses + Eurostat",
        components: []
    )

    #expect(response.personalRate == nil)
    #expect(response.estimatedAnnualImpact == nil)
    #expect(response.components.isEmpty)
}
