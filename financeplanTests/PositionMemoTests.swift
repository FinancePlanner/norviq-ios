//
//  PositionMemoTests.swift
//  financeplanTests
//

import StockPlanShared
import XCTest
@testable import financeplan

final class PositionMemoTests: XCTestCase {
    private func message(_ content: String, role: AIAssistantRole = .assistant) -> AIMessageResponse {
        AIMessageResponse(id: UUID().uuidString, conversationId: "c", role: role, content: content, createdAt: "2026-09-22T00:00:00Z")
    }

    func testAnnouncementYieldsTheSymbol() {
        XCTAssertEqual(PositionMemoAnnouncement.symbol(in: message("Memo on GRAB is ready.")), "GRAB")
    }

    func testOrdinaryRepliesAndUserLinesAreNotAnnouncements() {
        XCTAssertNil(PositionMemoAnnouncement.symbol(in: message("Your budget is fine.")))
        XCTAssertNil(PositionMemoAnnouncement.symbol(in: message("Memo on GRAB is ready.", role: .user)))
        XCTAssertNil(PositionMemoAnnouncement.symbol(in: message("Memo on is ready.")))
    }

    func testMarkFormatting() {
        XCTAssertEqual(PositionMemoFormat.price(2.77, "EUR"), "2.77 EUR")
        XCTAssertEqual(PositionMemoFormat.percent(-32.44), "-32.4%")
        XCTAssertEqual(PositionMemoFormat.percent(48.0), "+48.0%")
    }

    func testTurnWithMemoDecodes() throws {
        let json = """
        {"kind":"message","conversationId":"c","message":{"id":"m","conversationId":"c","role":"assistant","content":"Memo on GRAB is ready.","createdAt":"2026-09-22T00:00:00Z"},
         "memo":{"id":"x","symbol":"GRAB","title":"Grab","verdict":"Q would not add here.","bookmarked":false}}
        """
        let turn = try JSONDecoder.stockPlanShared.decode(AIAssistantTurnResponse.self, from: Data(json.utf8))
        XCTAssertEqual(turn.memo?.symbol, "GRAB")
    }
}
