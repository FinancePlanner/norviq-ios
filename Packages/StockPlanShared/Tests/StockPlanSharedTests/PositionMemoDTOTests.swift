import Foundation
import StockPlanShared
import Testing

@Suite("Position memo DTOs")
struct PositionMemoDTOTests {
    @Test("A turn without a memo still decodes")
    func turnWithoutMemo() throws {
        let json = """
        {"kind":"message","conversationId":"11111111-1111-1111-1111-111111111111","message":{"id":"22222222-2222-2222-2222-222222222222","conversationId":"11111111-1111-1111-1111-111111111111","role":"assistant","content":"Hello","createdAt":"2026-09-22T15:00:00Z"}}
        """
        let turn = try JSONDecoder().decode(AIAssistantTurnResponse.self, from: Data(json.utf8))
        #expect(turn.memo == nil)
        #expect(turn.message.content == "Hello")
    }

    @Test("A memo card round-trips")
    func cardRoundTrip() throws {
        let card = PositionMemoCard(
            id: "abc",
            symbol: "GRAB",
            title: "GRAB memo",
            verdict: "Q would not add.",
            bookmarked: false
        )
        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(PositionMemoCard.self, from: data)
        #expect(decoded == card)
    }
}
