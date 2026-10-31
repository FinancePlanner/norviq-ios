import Foundation
import StockPlanShared
import Testing

@Suite("PilotDTOs")
struct PilotDTOsTests {
    @Test("follow request round-trips with camelCase keys")
    func createRequestRoundTrip() throws {
        let request = PilotFollowCreateRequest(
            pilotSlug: "nancy-pelosi",
            targetKind: .portfolio,
            portfolioListId: nil,
            watchlistListId: nil,
            startingCapital: 10000
        )
        let data = try JSONEncoder().encode(request)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"pilotSlug\":\"nancy-pelosi\""))
        #expect(json.contains("\"targetKind\":\"portfolio\""))
        #expect(try JSONDecoder().decode(PilotFollowCreateRequest.self, from: data) == request)
    }

    @Test("watchlist status decodes exited")
    func exitedStatus() throws {
        let decoded = try JSONDecoder().decode([WatchlistStatus].self, from: Data("[\"exited\"]".utf8))
        #expect(decoded == [.exited])
    }

    @Test("an unknown watchlist status decodes as active, so a newer server never breaks an older client")
    func unknownStatusIsActive() throws {
        let decoded = try JSONDecoder().decode(
            [WatchlistStatus].self,
            from: Data("[\"something_new\", \"exited\", \"ready\"]".utf8)
        )
        #expect(decoded == [.active, .exited, .ready])
        let encoded = try String(decoding: JSONEncoder().encode([WatchlistStatus.exited]), as: UTF8.self)
        #expect(encoded == "[\"exited\"]")
    }
}
