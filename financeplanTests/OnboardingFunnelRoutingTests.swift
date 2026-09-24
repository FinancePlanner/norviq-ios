import Foundation
import StockPlanShared
import Testing
@testable import financeplan

@Suite("Onboarding funnel routing")
struct OnboardingFunnelRoutingTests {
    private let finished = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("A finished funnel goes Home whatever the device remembers")
    func funnelFinished() {
        let route = OnboardingFunnelRouting.route(
            server: OnboardingStateDTO(funnelStep: "budget", funnelCompletedAt: finished),
            localRequiresQuestionnaire: true, localHasImported: false, hasUserID: true
        )
        #expect(route.requiresQuestionnaire == false)
        #expect(route.requiresImport == false)
    }

    @Test("A funnel left at the paywall on the web resumes at the paywall", arguments: ["questionnaire", "paywall"])
    func paywall(_ step: String) {
        let route = OnboardingFunnelRouting.route(
            server: OnboardingStateDTO(funnelStep: step),
            localRequiresQuestionnaire: false, localHasImported: true, hasUserID: true
        )
        #expect(route.requiresQuestionnaire)
        #expect(route.requiresImport)
    }

    @Test("A funnel left at import or budget resumes in the import flow", arguments: [nil, "welcome", "import", "budget"])
    func importFlow(_ step: String?) {
        let route = OnboardingFunnelRouting.route(
            server: OnboardingStateDTO(funnelStep: step),
            localRequiresQuestionnaire: false, localHasImported: true, hasUserID: true
        )
        #expect(route.requiresQuestionnaire == false)
        #expect(route.requiresImport)
    }

    @Test("An unreadable server falls back to the device flags")
    func offline() {
        let route = OnboardingFunnelRouting.route(
            server: nil, localRequiresQuestionnaire: false, localHasImported: true, hasUserID: true
        )
        #expect(route.requiresQuestionnaire == false)
        #expect(route.requiresImport == false)
    }

    @Test("A server step past the paywall outranks a stale device questionnaire flag")
    func serverStepOutranksLocalFlag() {
        let route = OnboardingFunnelRouting.route(
            server: OnboardingStateDTO(funnelStep: "import"),
            localRequiresQuestionnaire: true, localHasImported: true, hasUserID: true
        )
        #expect(route.requiresQuestionnaire == false)
        #expect(route.requiresImport)
    }

    @Test("A fresh signup with no server step yet still owes the paywall")
    func noServerStepYetUsesLocalFlag() {
        let route = OnboardingFunnelRouting.route(
            server: OnboardingStateDTO(funnelStep: nil),
            localRequiresQuestionnaire: true, localHasImported: true, hasUserID: true
        )
        #expect(route.requiresQuestionnaire)
        #expect(route.requiresImport)
    }
}
