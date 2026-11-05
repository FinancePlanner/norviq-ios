@testable import financeplan
import XCTest

final class QuickAssistantVoiceTests: XCTestCase {
    func testSpokenTextDropsMarkdownMarkers() {
        let reply = """
        ## November
        You spent **€214.60** on *groceries*, see [details](https://norviq.org/x).
        - Week 1: `€11`
        1. Week 2: €22
        > Under plan
        """
        XCTAssertEqual(
            VoiceReplySpeaker.spokenText(from: reply),
            "November. You spent €214.60 on groceries, see details. Week 1: €11. Week 2: €22. Under plan."
        )
    }

    func testSpokenTextReadsTableRowsWithoutPipes() {
        let reply = """
        | Month | Spent |
        |---|---|
        | May | €10 |
        """
        XCTAssertEqual(VoiceReplySpeaker.spokenText(from: reply), "Month, Spent. May, €10.")
    }

    func testSpokenTextIsEmptyForBlankReply() {
        XCTAssertEqual(VoiceReplySpeaker.spokenText(from: " \n "), "")
    }

    func testSpeechIdentifiersAreFullLocales() {
        XCTAssertEqual(AppLanguage.english.speechIdentifier, "en-US")
        XCTAssertEqual(AppLanguage.portuguesePortugal.speechIdentifier, "pt-PT")
    }
}
