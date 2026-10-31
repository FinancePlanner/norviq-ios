import Foundation
import Testing
@testable import StockPlanShared

@Suite("Scenario contracts")
struct ScenarioDTOTests {
    @Test
    func `all supported asset categories remain codable`() throws {
        let data = try JSONEncoder().encode(AssetCategory.allCases)
        let decoded = try JSONDecoder().decode([AssetCategory].self, from: data)
        #expect(decoded == [.stock, .etf, .mutualFund, .crypto, .cash, .bond, .realEstate, .commodity])
    }

    @Test(arguments: [
        ScenarioConfiguration.historical(.init(catalogId: "covid_crash")),
        ScenarioConfiguration.custom(.init(horizonMonths: 12)),
        ScenarioConfiguration.monteCarlo(.init(horizonMonths: 360)),
    ])
    func `tagged configurations round trip`(_ configuration: ScenarioConfiguration) throws {
        let data = try JSONEncoder().encode(configuration)
        #expect(try JSONDecoder().decode(ScenarioConfiguration.self, from: data) == configuration)
    }

    @Test
    func `monte carlo validation enforces documented limits`() {
        #expect(throws: ScenarioValidationError.invalidPathCount) {
            try ScenarioConfiguration.monteCarlo(.init(pathCount: 50001, horizonMonths: 360)).validate()
        }
        #expect(throws: ScenarioValidationError.invalidHorizon) {
            try ScenarioConfiguration.monteCarlo(.init(horizonMonths: 601)).validate()
        }
        #expect(throws: ScenarioValidationError.invalidDegreesOfFreedom) {
            try ScenarioConfiguration.monteCarlo(
                .init(distribution: .studentT, horizonMonths: 120, degreesOfFreedom: 2)
            ).validate()
        }
    }

    @Test
    func `comparison accepts at most four results`() {
        let result = ScenarioResult(id: "result", runId: "run", timeline: [], maximumDrawdown: 0)
        #expect(throws: ScenarioValidationError.tooManyComparisons) {
            _ = try ScenarioComparison(results: Array(repeating: result, count: 5))
        }
    }

    @Test
    func `scenario result impact fields round trip`() throws {
        let result = ScenarioResult(
            id: "result", runId: "run", timeline: [.init(elapsedMonths: 0, value: 100_000)],
            maximumDrawdown: 0.22, endingValue: 78000, portfolioChangePercent: -0.22,
            goalDelayMonths: 14, requiredMonthlyContribution: 680, contributionDelta: 180,
            recoveryMonths: 18, expenseImpactMonthly: 180
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let data = try encoder.encode(result)
        let decoded = try decoder.decode(ScenarioResult.self, from: data)
        #expect(decoded.endingValue == 78000)
        #expect(decoded.portfolioChangePercent == -0.22)
        #expect(decoded.goalDelayMonths == 14)
        #expect(decoded.requiredMonthlyContribution == 680)
        #expect(decoded.contributionDelta == 180)
        #expect(decoded.recoveryMonths == 18)
        #expect(decoded.expenseImpactMonthly == 180)
        #expect(decoded.maximumDrawdown == 0.22)
    }

    @Test
    func `scenario result decodes without impact fields for backward compatibility`() throws {
        let json = Data(
            #"{"id":"r","runId":"run","timeline":[],"percentileBands":[],"maximumDrawdown":0.1,"holdingContributions":[],"classContributions":[],"assumptions":{},"warnings":[]}"#
                .utf8
        )
        let decoded = try JSONDecoder().decode(ScenarioResult.self, from: json)
        #expect(decoded.maximumDrawdown == 0.1)
        #expect(decoded.goalDelayMonths == nil)
        #expect(decoded.endingValue == nil)
    }
}
