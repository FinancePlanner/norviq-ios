import Foundation
import Testing
@testable import StockPlanShared

@Suite("Groups DTOs")
struct GroupsDTOsTests {
    private static let now = Date(timeIntervalSince1970: 1_790_000_000)

    private static func summary(membership: GroupMembership? = nil) -> GroupSummary {
        GroupSummary(
            id: UUID(), name: "$AAPL holders", description: "", iconEmoji: "🍎",
            topic: .stock, ticker: "AAPL", visibility: .private, memberCount: 3,
            defaultChannelId: UUID(), lastMessageAt: now,
            lastMessage: GroupMessagePreview(authorUsername: "ana", excerpt: "earnings tonight", createdAt: now),
            unreadCount: 2, membership: membership, createdAt: now
        )
    }

    @Test("A group detail round-trips through the shared coders")
    func detailRoundTrip() throws {
        let group = Self.summary(membership: GroupMembership(role: .owner, pushEnabled: true, joinedAt: Self.now))
        let detail = GroupDetail(
            group: group,
            channels: [GroupChannel(
                id: UUID(), groupId: group.id, name: "general", kind: .text, topic: nil, position: 0,
                lastSeq: 42, lastMessageAt: Self.now, lastReadSeq: 40, unreadCount: 2
            )],
            permissions: GroupPermissions(
                canPost: true, canInvite: true, canEdit: true,
                canManageChannels: true, canModerate: true, canDelete: true
            ),
            ownerUsername: "ana"
        )
        let data = try JSONEncoder.stockPlanShared.encode(detail)
        #expect(try JSONDecoder.stockPlanShared.decode(GroupDetail.self, from: data) == detail)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"visibility\":\"private\""))
        #expect(json.contains("\"last_read_seq\":40"))
    }

    @Test("Unknown topic, role, channel kind and event type decode as .other")
    func unknownValuesAreTolerated() throws {
        let json = """
        {"type":"typing","group_id":null}
        """
        let event = try JSONDecoder.stockPlanShared.decode(GroupRealtimeEvent.self, from: Data(json.utf8))
        #expect(event.type == .other)

        let decoder = JSONDecoder.stockPlanShared
        #expect(try decoder.decode(GroupTopic.self, from: Data("\"sector\"".utf8)) == .other)
        #expect(try decoder.decode(GroupRole.self, from: Data("\"moderator\"".utf8)) == .other)
        #expect(try decoder.decode(GroupChannelKind.self, from: Data("\"forum\"".utf8)) == .other)
        #expect(try decoder.decode(GroupMembershipRemovalReason.self, from: Data("\"expired\"".utf8)) == .other)
    }

    @Test("A deleted message is a tombstone with no body")
    func tombstone() throws {
        let message = GroupMessage(
            id: UUID(), groupId: UUID(), channelId: UUID(), seq: 7, clientMessageId: "c-1",
            authorId: UUID(), authorUsername: "bo", body: nil, isDeleted: true, createdAt: Self.now
        )
        let event = GroupRealtimeEvent(
            type: .messageCreated,
            groupId: message.groupId,
            channelId: message.channelId,
            message: message
        )
        let data = try JSONEncoder.stockPlanShared.encode(event)
        let decoded = try JSONDecoder.stockPlanShared.decode(GroupRealtimeEvent.self, from: data)
        #expect(decoded == event)
        #expect(decoded.message?.body == nil)
        #expect(String(decoding: data, as: UTF8.self).contains("\"type\":\"message.created\""))
    }

    @Test("Ticker topics and managing roles")
    func helpers() {
        #expect(GroupTopic.stock.allowsTicker)
        #expect(GroupTopic.crypto.allowsTicker)
        #expect(!GroupTopic.community.allowsTicker)
        #expect(GroupRole.owner.canManage)
        #expect(GroupRole.admin.canManage)
        #expect(!GroupRole.member.canManage)
        #expect(!GroupRole.other.canManage)
        #expect(CreateGroupInviteRequest.default.expiresInHours == 168)
    }

    @Test("A board report without group fields still decodes")
    func boardReportWithoutGroupFields() throws {
        let json = """
        {"id":"\(UUID().uuidString)","reporter_username":"ana","post_id":"\(UUID().uuidString)",
        "comment_id":null,"board_slug":"dca","excerpt":"t","target_author_username":"bo",
        "reason":"spam","note":null,"created_at":"2026-10-02T10:00:00Z"}
        """
        let item = try JSONDecoder.stockPlanShared.decode(BoardReportItem.self, from: Data(json.utf8))
        #expect(item.groupId == nil)
        #expect(item.groupMessageId == nil)
        #expect(item.boardSlug == "dca")
    }
}
