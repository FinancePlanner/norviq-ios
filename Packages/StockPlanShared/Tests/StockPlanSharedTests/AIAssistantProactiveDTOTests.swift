import Foundation
import StockPlanShared
import Testing

@Suite("Assistant proactive + standing-task DTOs")
struct AIAssistantProactiveDTOTests {
    private let legacyMessage = """
    {"id":"22222222-2222-2222-2222-222222222222","conversationId":"11111111-1111-1111-1111-111111111111","role":"assistant","content":"Hello","createdAt":"2026-09-22T15:00:00Z"}
    """

    @Test("A message from an older server decodes with no origin or label")
    func legacyMessageDecodes() throws {
        let message = try JSONDecoder().decode(AIMessageResponse.self, from: Data(legacyMessage.utf8))
        #expect(message.origin == nil)
        #expect(message.sourceLabel == nil)
        #expect(message.content == "Hello")
    }

    @Test("A proactive message carries its origin and caption")
    func proactiveMessageDecodes() throws {
        let json = """
        {"id":"a","conversationId":"c","role":"assistant","content":"NVDA crossed 120.","createdAt":"2026-09-22T15:00:00Z","origin":"proactive","sourceLabel":"Standing task"}
        """
        let message = try JSONDecoder().decode(AIMessageResponse.self, from: Data(json.utf8))
        #expect(message.origin == .proactive)
        #expect(message.sourceLabel == "Standing task")
    }

    @Test("An origin this client does not know reads as absent instead of failing")
    func unknownOriginIsLenient() throws {
        let json = """
        {"id":"a","conversationId":"c","role":"assistant","content":"x","createdAt":"2026-09-22T15:00:00Z","origin":"briefing"}
        """
        let message = try JSONDecoder().decode(AIMessageResponse.self, from: Data(json.utf8))
        #expect(message.origin == nil)
    }

    @Test("A reply without a caption encodes without the optional keys")
    func encodingOmitsNil() throws {
        let message = AIMessageResponse(id: "a", conversationId: "c", role: .assistant, content: "x", createdAt: "t")
        let text = try String(decoding: JSONEncoder().encode(message), as: UTF8.self)
        #expect(!text.contains("origin"))
        #expect(!text.contains("sourceLabel"))
    }

    @Test("A turn with a watch proposal round-trips; a legacy turn has none")
    func turnWatchProposal() throws {
        let legacy = """
        {"kind":"message","conversationId":"c","message":\(legacyMessage)}
        """
        #expect(try JSONDecoder().decode(AIAssistantTurnResponse.self, from: Data(legacy.utf8)).watchProposal == nil)

        let turn = AIAssistantTurnResponse(
            kind: .confirmationRequired,
            conversationId: "c",
            message: AIMessageResponse(
                id: "m",
                conversationId: "c",
                role: .assistant,
                content: "Want me to?",
                createdAt: "t",
                origin: .reply
            ),
            pendingAction: AIPendingActionResponse(
                id: "p",
                conversationId: "c",
                toolName: "create_watch",
                summary: "s",
                arguments: "{}",
                status: .pending,
                expiresAt: "t",
                createdAt: "t"
            ),
            watchProposal: AIWatchProposalResponse(
                title: "Watch NVDA",
                scheduleHuman: "Every hour",
                intervalMinutes: 60,
                spec: "Tell me when NVDA drops below 100"
            )
        )
        let decoded = try JSONDecoder().decode(AIAssistantTurnResponse.self, from: JSONEncoder().encode(turn))
        #expect(decoded == turn)
        #expect(decoded.watchProposal?.intervalMinutes == 60)
    }
}
