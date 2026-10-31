import Foundation
import Testing
@testable import StockPlanShared

@Suite("Board notification DTOs")
struct BoardNotificationsDTOsTests {
    @Test("An unknown kind decodes as .other instead of failing the page")
    func unknownKindIsTolerated() throws {
        let json = """
        {"items":[{"id":"\(UUID().uuidString)","kind":"mention","actor_username":"ana",
        "post_id":"\(UUID().uuidString)","board_slug":"dca","post_title":"t","comment_id":null,
        "excerpt":null,"created_at":"2026-10-02T10:00:00Z","is_read":false}],
        "next_cursor":null,"unread_count":1}
        """
        let page = try JSONDecoder.stockPlanShared.decode(BoardNotificationPage.self, from: Data(json.utf8))
        #expect(page.items.first?.kind == .other)
        #expect(page.unreadCount == 1)
    }

    @Test("A page round-trips through the shared coders")
    func roundTrip() throws {
        let page = BoardNotificationPage(
            items: [BoardNotification(
                id: UUID(), kind: .reply, actorUsername: "bo", postId: UUID(), boardSlug: "dca",
                postTitle: "Why I DCA", commentId: UUID(), excerpt: "Same here",
                createdAt: Date(timeIntervalSince1970: 1_790_000_000), isRead: false
            )],
            nextCursor: "abc",
            unreadCount: 3
        )
        let data = try JSONEncoder.stockPlanShared.encode(page)
        #expect(try JSONDecoder.stockPlanShared.decode(BoardNotificationPage.self, from: data) == page)
        #expect(BoardNotificationKind.reply.rawValue == "reply")
        #expect(BoardNotificationSettings.default == BoardNotificationSettings(replyPush: true, upvotePush: true))
    }
}
