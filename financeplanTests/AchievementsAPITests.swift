import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class AchievementsAPITests: XCTestCase {
  private final class SessionMock: HTTPClientSession, @unchecked Sendable {
    var handler: ((URLRequest) throws -> (Data, URLResponse))?
    private(set) var requests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      requests.append(request)
      guard let handler else {
        fatalError("SessionMock.handler must be configured before use")
      }
      return try handler(request)
    }
  }

  private let baseURL = URL(string: "https://api.example.com")!

  private func respond(_ request: URLRequest, status: Int, body: String) throws -> (Data, URLResponse) {
    let response = try XCTUnwrap(
      HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: status, httpVersion: nil, headerFields: nil)
    )
    return (Data(body.utf8), response)
  }

  private func jsonBody(_ request: URLRequest) throws -> [String: Any] {
    let data = try XCTUnwrap(request.httpBody)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  static let achievementsFixture = #"""
  {
    "summary": {"unlocked": 3, "total": 40, "hiddenRemaining": 1},
    "categories": [{"key": "discipline", "title": "Discipline"}, {"key": "performance", "title": "Performance"}],
    "achievements": [
      {"key": "start.first_holding", "category": "getting_started", "title": "First Holding",
       "description": "Add your first holding.", "iconKey": "chart.line.uptrend.xyaxis", "state": "earned",
       "currentTier": "", "progress": null, "isPerformance": false,
       "tiers": [{"tier": "", "threshold": 1, "xp": 25, "unlockId": "11111111-1111-1111-1111-111111111111",
                  "unlockedAt": "2026-10-20T10:00:00Z", "showcaseRank": 1}]},
      {"key": "discipline.check_in", "category": "discipline", "title": "Showing Up",
       "description": "Check in on consecutive days.", "iconKey": "flame.fill", "state": "inProgress",
       "currentTier": "bronze", "progress": {"current": 9, "target": 30}, "isPerformance": false,
       "tiers": [{"tier": "bronze", "threshold": 7, "xp": 25, "unlockId": "22222222-2222-2222-2222-222222222222",
                  "unlockedAt": "2026-10-21T10:00:00Z", "showcaseRank": null},
                 {"tier": "silver", "threshold": 30, "xp": 50, "unlockId": null, "unlockedAt": null, "showcaseRank": null},
                 {"tier": "gold", "threshold": 100, "xp": 100, "unlockId": null, "unlockedAt": null, "showcaseRank": null}]},
      {"key": "hidden.1", "category": "hidden", "title": "???", "description": "Keep exploring.",
       "iconKey": "lock", "state": "hidden", "currentTier": null, "progress": null, "isPerformance": false,
       "tiers": [{"tier": "", "threshold": null, "xp": 0, "unlockId": null, "unlockedAt": null, "showcaseRank": null}]},
      {"key": "perf.comeback", "category": "performance", "title": "Comeback",
       "description": "Recover from a drawdown.", "iconKey": "arrow.uturn.up.circle.fill", "state": "locked",
       "currentTier": null, "progress": null, "isPerformance": true,
       "tiers": [{"tier": "", "threshold": 1, "xp": 100, "unlockId": null, "unlockedAt": null, "showcaseRank": null}]}
    ]
  }
  """#

  // MARK: - Decoding

  func testAchievementsResponseDecodesEveryState() throws {
    let response = try JSONDecoder.stockPlanShared.decode(
      AchievementsResponse.self, from: Data(Self.achievementsFixture.utf8)
    )
    XCTAssertEqual(response.summary.unlocked, 3)
    XCTAssertEqual(response.summary.hiddenRemaining, 1)
    XCTAssertEqual(response.categories.map(\.key), ["discipline", "performance"])
    XCTAssertEqual(response.achievements.map(\.state), [.earned, .inProgress, .hidden, .locked])

    let checkIn = response.achievements[1]
    XCTAssertEqual(checkIn.progress, AchievementProgress(current: 9, target: 30))
    XCTAssertEqual(checkIn.currentTier, "bronze")
    XCTAssertEqual(checkIn.tiers.map(\.threshold), [7, 30, 100])
    XCTAssertNotNil(checkIn.tiers[0].unlockedAt)

    XCTAssertEqual(response.achievements[0].tiers.first?.showcaseRank, 1)
    XCTAssertNil(response.achievements[2].tiers.first?.threshold)
    XCTAssertTrue(response.achievements[3].isPerformance)
    XCTAssertNil(response.achievements[3].progress)
  }

  func testUnknownAchievementStateDecodesAsLocked() throws {
    let json = #"{"key":"x","category":"c","title":"t","description":"d","iconKey":"star","state":"brandNew","currentTier":null,"progress":null,"isPerformance":false,"tiers":[]}"#
    let achievement = try JSONDecoder.stockPlanShared.decode(Achievement.self, from: Data(json.utf8))
    XCTAssertEqual(achievement.state, .locked)
  }

  func testUnlockDecodes() throws {
    let json = #"[{"id":"33333333-3333-3333-3333-333333333333","key":"craft.thesis","tier":"silver","title":"Thesis Writer","description":"Write theses.","iconKey":"book.fill","xp":50,"unlockedAt":"2026-10-22T08:00:00Z"}]"#
    let unlocks = try JSONDecoder.stockPlanShared.decode([AchievementUnlock].self, from: Data(json.utf8))
    XCTAssertEqual(unlocks.first?.id, "33333333-3333-3333-3333-333333333333")
    XCTAssertEqual(unlocks.first?.tier, "silver")
    XCTAssertEqual(unlocks.first?.xp, 50)
  }

  func testConfigWithoutAchievementFlagsReadsAsOff() throws {
    let json = Data(#"{"enabled":true,"contactsDiscovery":false,"xImport":false,"leaderboards":true,"messaging":false}"#.utf8)
    let config = try JSONDecoder().decode(SocialConfig.self, from: json)
    XCTAssertFalse(config.achievements)
    XCTAssertFalse(config.activityFeed)
    XCTAssertFalse(SocialConfig.disabled.achievements)
  }

  func testConfigDecodesAchievementFlags() throws {
    let json = Data(
      #"{"enabled":true,"contactsDiscovery":false,"xImport":false,"leaderboards":true,"messaging":false,"achievements":true,"activityFeed":true}"#.utf8
    )
    let config = try JSONDecoder().decode(SocialConfig.self, from: json)
    XCTAssertTrue(config.achievements)
    XCTAssertTrue(config.activityFeed)
  }

  func testPrivacyWithoutShowAchievementsReadsAsShown() throws {
    let json = Data(
      #"{"searchVisibility":"everyone","discoverableByContacts":true,"discoverableByX":true,"showReturnPercent":false,"showStreaks":true,"showXP":true,"leaderboardOptIn":true}"#.utf8
    )
    let settings = try JSONDecoder().decode(SocialPrivacySettings.self, from: json)
    XCTAssertTrue(settings.showAchievements)
    XCTAssertTrue(SocialPrivacySettings.default.showAchievements)
  }

  func testPrivacyDecodesShowAchievementsOff() throws {
    let json = Data(
      #"{"searchVisibility":"everyone","discoverableByContacts":true,"discoverableByX":true,"showReturnPercent":false,"showStreaks":true,"showXP":true,"leaderboardOptIn":true,"showAchievements":false}"#.utf8
    )
    let settings = try JSONDecoder().decode(SocialPrivacySettings.self, from: json)
    XCTAssertFalse(settings.showAchievements)
  }

  func testProfileDecodesShowcaseWhenPresent() throws {
    let user = #"{"id":"u1","username":"ana","displayName":null,"avatarUrl":null,"friendshipStatus":"friends","mutualFriendCount":0}"#
    let with = #"{"user":\#(user),"badgeCount":4,"showcase":[{"key":"craft.thesis","tier":"gold","title":"Thesis Writer","iconKey":"book.fill"}]}"#
    let without = #"{"user":\#(user),"badgeCount":null}"#
    let profile = try JSONDecoder.stockPlanShared.decode(SocialProfile.self, from: Data(with.utf8))
    XCTAssertEqual(profile.showcase?.first?.title, "Thesis Writer")
    XCTAssertEqual(profile.badgeCount, 4)
    let bare = try JSONDecoder.stockPlanShared.decode(SocialProfile.self, from: Data(without.utf8))
    XCTAssertNil(bare.showcase)
  }

  func testFeedPageDecodes() throws {
    let json = #"""
    {"items":[{"id":"a1","actor":{"id":"u1","username":"ana","displayName":null,"avatarUrl":null,"friendshipStatus":"friends","mutualFriendCount":2},
      "achievement":{"key":"craft.thesis","tier":"bronze","title":"Thesis Writer","iconKey":"book.fill"},
      "createdAt":"2026-10-22T08:00:00Z","congratsCount":2,"viewerCongratulated":true}],
     "nextCursor":null}
    """#
    let page = try JSONDecoder.stockPlanShared.decode(SocialFeedResponse.self, from: Data(json.utf8))
    XCTAssertEqual(page.items.count, 1)
    XCTAssertEqual(page.items.first?.actor.username, "ana")
    XCTAssertEqual(page.items.first?.achievement.tier, "bronze")
    XCTAssertTrue(page.items.first?.viewerCongratulated ?? false)
    XCTAssertNil(page.nextCursor)
  }

  // MARK: - Requests

  func testAchievementsClientPathsAndBodies() async throws {
    let session = SessionMock()
    session.handler = { request in
      switch (request.httpMethod, request.url?.path) {
      case ("GET", "/v1/achievements"), ("PUT", "/v1/achievements/showcase"):
        return try self.respond(request, status: 200, body: Self.achievementsFixture)
      case ("GET", "/v1/achievements/unseen"):
        return try self.respond(request, status: 200, body: "[]")
      case ("POST", "/v1/achievements/seen"):
        return try self.respond(request, status: 204, body: "")
      default:
        XCTFail("Unexpected \(request.httpMethod ?? "") \(request.url?.path ?? "")")
        return try self.respond(request, status: 404, body: "")
      }
    }
    let client = AchievementsHTTPClient(
      baseURL: baseURL, session: session, authTokenProvider: { "t" }, languageProvider: { .english }
    )

    _ = try await client.list()
    _ = try await client.unseen()
    try await client.markSeen(ids: ["a", "b"])
    _ = try await client.setShowcase(items: [AchievementShowcaseItem(key: "craft.thesis", tier: "gold")])

    let seen = try XCTUnwrap(session.requests.first { $0.url?.path == "/v1/achievements/seen" })
    XCTAssertEqual(try jsonBody(seen)["ids"] as? [String], ["a", "b"])
    let showcase = try XCTUnwrap(session.requests.first { $0.url?.path == "/v1/achievements/showcase" })
    let items = try XCTUnwrap(try jsonBody(showcase)["items"] as? [[String: String]])
    XCTAssertEqual(items, [["key": "craft.thesis", "tier": "gold"]])
  }

  func testSocialFeedClientRequests() async throws {
    let session = SessionMock()
    session.handler = { request in
      switch (request.httpMethod, request.url?.path) {
      case ("GET", "/v1/social/feed"):
        return try self.respond(request, status: 200, body: #"{"items":[],"nextCursor":null}"#)
      case ("POST", "/v1/social/feed/act-1/congrats"):
        return try self.respond(request, status: 204, body: "")
      case ("GET", "/v1/social/users/u1/achievements"):
        return try self.respond(request, status: 200, body: "[]")
      default:
        XCTFail("Unexpected \(request.httpMethod ?? "") \(request.url?.path ?? "")")
        return try self.respond(request, status: 404, body: "")
      }
    }
    let client = SocialHTTPClient(baseURL: baseURL, session: session, authTokenProvider: { "t" })

    _ = try await client.feed(cursor: "abc", limit: 20)
    try await client.congratulate(activityId: "act-1")
    _ = try await client.friendAchievements(userId: "u1")

    let feed = try XCTUnwrap(session.requests.first { $0.url?.path == "/v1/social/feed" })
    let query = URLComponents(url: try XCTUnwrap(feed.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
    XCTAssertEqual(query.first { $0.name == "cursor" }?.value, "abc")
    XCTAssertEqual(query.first { $0.name == "limit" }?.value, "20")
  }

  func testFirstFeedPageSendsNoCursor() async throws {
    let session = SessionMock()
    session.handler = { request in try self.respond(request, status: 200, body: #"{"items":[],"nextCursor":null}"#) }
    let client = SocialHTTPClient(baseURL: baseURL, session: session, authTokenProvider: { "t" })
    _ = try await client.feed(cursor: nil, limit: 20)
    let query = URLComponents(url: try XCTUnwrap(session.requests.first?.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
    XCTAssertNil(query.first { $0.name == "cursor" })
  }

  func testRequestsCarryTheAppLanguage() async throws {
    let session = SessionMock()
    session.handler = { request in try self.respond(request, status: 200, body: "[]") }
    let achievements = AchievementsHTTPClient(
      baseURL: baseURL, session: session, authTokenProvider: { "t" }, languageProvider: { .portuguesePortugal }
    )
    _ = try await achievements.unseen()
    XCTAssertEqual(session.requests.last?.value(forHTTPHeaderField: "Accept-Language"), "pt-PT")

    let social = SocialHTTPClient(
      baseURL: baseURL, session: session, authTokenProvider: { "t" }, languageProvider: { .english }
    )
    _ = try await social.friendAchievements(userId: "u1")
    XCTAssertEqual(session.requests.last?.value(forHTTPHeaderField: "Accept-Language"), "en")
  }
}
