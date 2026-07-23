//
//  AssistantCommandsTests.swift
//  financeplanTests
//

import XCTest
@testable import financeplan

final class AssistantCommandsTests: XCTestCase {
    func testPlainTextPassesThrough() {
        let resolution = AssistantCommandParser.resolve("How is my portfolio doing?")
        XCTAssertEqual(resolution, .plain("How is my portfolio doing?"))
    }

    func testKnownCommandExpandsPrompt() throws {
        guard case let .command(command, expandedPrompt) = AssistantCommandParser.resolve("/expenses") else {
            return XCTFail("Expected a command resolution")
        }
        XCTAssertEqual(command.id, "expenses")
        XCTAssertTrue(expandedPrompt.contains("expense"))
        XCTAssertFalse(expandedPrompt.hasPrefix("/"))
    }

    func testCommandArgumentsFlowIntoPrompt() throws {
        guard case let .command(command, expandedPrompt) = AssistantCommandParser.resolve("/stocks AAPL") else {
            return XCTFail("Expected a command resolution")
        }
        XCTAssertEqual(command.id, "stocks")
        XCTAssertTrue(expandedPrompt.contains("AAPL"))
    }

    func testCommandsAreCaseInsensitive() throws {
        guard case let .command(command, _) = AssistantCommandParser.resolve("/Portfolio") else {
            return XCTFail("Expected a command resolution")
        }
        XCTAssertEqual(command.id, "portfolio")
    }

    func testUnknownCommandAnswersLocallyWithHelp() throws {
        guard case let .local(reply) = AssistantCommandParser.resolve("/nonsense") else {
            return XCTFail("Expected a local resolution")
        }
        XCTAssertTrue(reply.contains("/nonsense"))
        XCTAssertTrue(reply.contains("/expenses"))
    }

    func testHelpCommandListsEveryRegisteredCommand() throws {
        guard case let .local(reply) = AssistantCommandParser.resolve("/help") else {
            return XCTFail("Expected a local resolution")
        }
        for command in AssistantCommandRegistry.all {
            XCTAssertTrue(reply.contains(command.trigger), "help should mention \(command.trigger)")
        }
    }

    func testSuggestionsFilterByPrefix() {
        XCTAssertEqual(AssistantCommandRegistry.suggestions(for: "/").count, AssistantCommandRegistry.all.count)
        XCTAssertEqual(AssistantCommandRegistry.suggestions(for: "/ex").map(\.id), ["expenses"])
        XCTAssertTrue(AssistantCommandRegistry.suggestions(for: "/expenses").isEmpty)
        XCTAssertTrue(AssistantCommandRegistry.suggestions(for: "/expenses this").isEmpty)
        XCTAssertTrue(AssistantCommandRegistry.suggestions(for: "hello").isEmpty)
    }
}
