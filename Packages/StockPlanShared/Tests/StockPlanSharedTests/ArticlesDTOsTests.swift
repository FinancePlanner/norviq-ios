import Foundation
import StockPlanShared
import Testing

@Suite("ArticlesDTOs")
struct ArticlesDTOsTests {
    private var encoder: JSONEncoder {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.outputFormatting = .sortedKeys
        return jsonEncoder
    }

    private var decoder: JSONDecoder {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        return jsonDecoder
    }

    @Test("write request round-trips with camelCase keys")
    func writeRequestRoundTrip() throws {
        let request = ArticleWriteRequest(
            title: "Why 2027 could reprice NEXT",
            bodyMarkdown: "Body",
            bulletPoints: ["First LNG in 1H 2027"],
            tickers: ["NEXT"],
            disclosure: "I hold $NEXT.",
            coverImageId: nil,
            source: .web
        )
        let data = try encoder.encode(request)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"bodyMarkdown\":\"Body\""))
        #expect(json.contains("\"bulletPoints\":[\"First LNG in 1H 2027\"]"))
        #expect(json.contains("\"source\":\"web\""))
        #expect(try decoder.decode(ArticleWriteRequest.self, from: data) == request)
    }

    @Test("detail round-trips including dates")
    func detailRoundTrip() throws {
        let summary = ArticleSummary(
            id: UUID(), code: "abcd2345", slug: "why-2027", title: "Why 2027",
            bulletPoints: ["One key point here"], tickers: ["NEXT"],
            author: ArticleAuthor(id: UUID(), username: "ana", avatarURL: nil),
            coverImageId: nil, upvoteCount: 6, viewCount: 1715, wordCount: 589,
            status: .published, source: .web,
            publishedAt: Date(timeIntervalSince1970: 1_790_000_000), editedAt: nil
        )
        let detail = ArticleDetail(
            article: summary,
            bodyMarkdown: "Body",
            disclosure: "No position",
            viewerUpvoted: true,
            viewerIsAuthor: false
        )
        let decoded = try decoder.decode(ArticleDetail.self, from: encoder.encode(detail))
        #expect(decoded == detail)
    }

    @Test("unknown status and source decode as .unknown so a newer server never breaks an older client")
    func unknownEnums() throws {
        let statuses = try decoder.decode([ArticleStatus].self, from: Data("[\"archived\",\"hidden\"]".utf8))
        let sources = try decoder.decode([ArticleSource].self, from: Data("[\"telegram\",\"discord\"]".utf8))
        #expect(statuses == [.unknown, .hidden])
        #expect(sources == [.unknown, .discord])
    }
}
