import Foundation
import Testing
@testable import StockPlanShared

struct OnboardingDTOsTests {
    @Test
    func `state decodes the camelCase ISO-8601 wire shape the backend sends`() throws {
        let json = """
        {"funnelStep":"budget","funnelCompletedAt":null,
         "addHoldingCompleted":true,"firstHoldingAt":"2026-09-24T10:00:00Z",
         "setBudgetCompleted":false,"firstBudgetAt":null,
         "setGoalCompleted":false,"firstGoalAt":null,
         "guidedStartDismissedAt":null}
        """
        let state = try JSONDecoder.makeStockPlanShared().decode(OnboardingStateDTO.self, from: Data(json.utf8))
        #expect(state.funnelStep == OnboardingFunnelStep.budget.rawValue)
        #expect(state.addHoldingCompleted)
        #expect(state.firstHoldingAt == ISO8601DateFormatter().date(from: "2026-09-24T10:00:00Z"))
        #expect(state.funnelCompletedAt == nil)
    }

    @Test
    func `patch encodes only the fields that are set`() throws {
        let data = try JSONEncoder().encode(OnboardingPatchRequest(guidedStartDismissed: true))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["guidedStartDismissed"])
    }

    @Test(arguments: OnboardingFunnelStep.allCases)
    func `funnel step ids match the contract`(_ step: OnboardingFunnelStep) {
        #expect(["questionnaire", "paywall", "welcome", "import", "budget", "done"].contains(step.rawValue))
    }
}
