import Foundation
import XCTest
@testable import financeplan

@MainActor
final class QuickAssistantStreamTests: XCTestCase {
    func testErrorFrameCarriesCode() throws {
        let event = try AssistantStreamClient.decodePersistent(
            event: "error",
            json: #"{"message":"Out of turns","code":"quota_exhausted"}"#
        )
        guard case let .error(message, code) = event else { return XCTFail("Expected an error event") }
        XCTAssertEqual(message, "Out of turns")
        XCTAssertEqual(code, "quota_exhausted")
    }

    func testErrorFrameFromOlderBackendHasNoCode() throws {
        let event = try AssistantStreamClient.decodePersistent(event: "error", json: #"{"message":"Nope"}"#)
        guard case let .error(message, code) = event else { return XCTFail("Expected an error event") }
        XCTAssertEqual(message, "Nope")
        XCTAssertNil(code)
    }

    func testTurnBodyOmitsContextWhenAbsent() throws {
        let body = try AssistantStreamClient.turnBody(content: "Hi", context: nil)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["content"] as? String, "Hi")
        XCTAssertNil(json["context"])
    }

    func testTurnBodySendsContext() throws {
        let context = AssistantTurnContext(screen: "expenses", timeZone: "Europe/Lisbon", locale: "pt-PT", inputMode: .voice)
        let body = try AssistantStreamClient.turnBody(content: "Hi", context: context)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let sent = try XCTUnwrap(json["context"] as? [String: String])
        XCTAssertEqual(sent, ["screen": "expenses", "timeZone": "Europe/Lisbon", "locale": "pt-PT", "inputMode": "voice"])
    }

    func testCurrentContextUsesAppLanguageAndDeviceZone() {
        let context = AssistantTurnContext.current(screen: .tax, inputMode: .text, language: .portuguesePortugal, timeZone: TimeZone(identifier: "Europe/Lisbon")!)
        XCTAssertEqual(context, AssistantTurnContext(screen: "tax", timeZone: "Europe/Lisbon", locale: "pt-PT", inputMode: .text))
    }

    func testConversationPayloadOmitsBindMessagingByDefault() throws {
        let data = try JSONEncoder().encode(AssistantCreateConversationPayload(title: "T"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(json["bindMessaging"])
    }

    func testConversationPayloadCanLeaveTelegramAlone() throws {
        let data = try JSONEncoder().encode(AssistantCreateConversationPayload(title: "T", bindMessaging: false))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["bindMessaging"] as? Bool, false)
    }
}
