import Foundation
import Testing
@testable import StockPlanShared

@Suite("Boards DTOs")
struct BoardsDTOsTests {
    @Test("Post page round-trips through the shared coders with snake_case keys")
    func postPageRoundTrip() throws {
        let post = BoardPostSummary(
            id: UUID(),
            boardSlug: "dca",
            kind: .link,
            title: "Monthly DCA check-in",
            url: "https://example.com/a",
            domain: "example.com",
            tags: ["dca", "etf"],
            authorUsername: "fernando",
            createdAt: Date(timeIntervalSince1970: 1_790_000_000),
            score: 3,
            commentCount: 2,
            participantCount: 2,
            viewCount: 9,
            viewerHasVoted: true,
            newCommentCount: nil
        )
        let page = BoardPostPage(items: [post], nextCursor: "abc")
        let data = try JSONEncoder.stockPlanShared.encode(page)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let item = try #require((json["items"] as? [[String: Any]])?.first)
        #expect(item["board_slug"] as? String == "dca")
        #expect(item["viewer_has_voted"] as? Bool == true)
        #expect(item["ai_generated"] as? Bool == false)
        #expect(json["next_cursor"] as? String == "abc")
        #expect(try JSONDecoder.stockPlanShared.decode(BoardPostPage.self, from: data) == page)
    }

    @Test("A daily post keeps its AI flag, and an older payload without the flag is a member post")
    func dailyPostFlag() throws {
        let post = BoardPostSummary(
            id: UUID(),
            boardSlug: "daily",
            kind: .text,
            title: "NVDA rose 4.2%",
            url: nil,
            domain: nil,
            tags: ["stock", "nvda", "ai"],
            authorUsername: "norviq",
            createdAt: Date(timeIntervalSince1970: 1_790_000_000),
            score: 1,
            commentCount: 0,
            participantCount: 1,
            viewCount: 0,
            viewerHasVoted: false,
            newCommentCount: nil,
            aiGenerated: true,
            aiTopic: .stock
        )
        let list = BoardListResponse(items: [], nextCursor: nil, dailyPost: post)
        let data = try JSONEncoder.stockPlanShared.encode(list)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let daily = try #require(json["daily_post"] as? [String: Any])
        #expect(daily["ai_generated"] as? Bool == true)
        #expect(daily["ai_topic"] as? String == "stock")
        #expect(try JSONDecoder.stockPlanShared.decode(BoardListResponse.self, from: data) == list)

        let legacy = """
        {"id":"\(post.id.uuidString)","board_slug":"dca","kind":"text","title":"Hello","tags":[],"created_at":"2026-09-26T17:46:40Z","score":0,"comment_count":0,"participant_count":1,"view_count":0,"viewer_has_voted":false}
        """
        let decoded = try JSONDecoder.stockPlanShared.decode(BoardPostSummary.self, from: Data(legacy.utf8))
        #expect(decoded.aiGenerated == false)
        #expect(decoded.aiTopic == nil)
    }

    @Test("Viewer status round-trips with and without a sanction")
    func viewerStatusRoundTrip() throws {
        let sanction = UserSanction(
            id: UUID(),
            username: "troll",
            kind: .mute,
            reason: "spam",
            expiresAt: Date(timeIntervalSince1970: 1_790_100_000),
            createdAt: Date(timeIntervalSince1970: 1_790_000_000),
            revokedAt: nil
        )
        for status in [
            CommunityViewerStatus(
                username: "fernando",
                isAdmin: false,
                guidelinesAccepted: true,
                hasUsername: true,
                activeSanction: sanction
            ),
            CommunityViewerStatus(
                username: nil,
                isAdmin: true,
                guidelinesAccepted: false,
                hasUsername: false,
                activeSanction: nil
            ),
        ] {
            let data = try JSONEncoder.stockPlanShared.encode(status)
            #expect(try JSONDecoder.stockPlanShared.decode(CommunityViewerStatus.self, from: data) == status)
        }
    }

    @Test("Enums keep their wire values")
    func enumWireValues() {
        #expect(BoardPostKind.allCases.map(\.rawValue) == ["link", "text", "ask", "show"])
        #expect(BoardPostSort.allCases.map(\.rawValue) == ["new", "top", "active"])
        #expect(CommunitySanctionKind.allCases.map(\.rawValue) == ["mute", "ban"])
    }
}
