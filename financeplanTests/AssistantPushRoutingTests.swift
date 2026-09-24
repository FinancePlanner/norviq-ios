import Combine
import Foundation
import StockPlanShared
import UserNotifications
import XCTest
@testable import financeplan

private let conversationID = "3f2c8a1e-9b4d-4c6e-8f10-2a7b5c9d0e11"
private let otherConversationID = "7a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d"
private let messageID = "0d9e8f7a-6b5c-4d3e-9f2a-1b0c9d8e7f6a"

private func backendPayload(
  conversationID: Any = conversationID,
  deepLink: Any = "financeplan://assistant/conversations/\(conversationID)",
  sourceLabel: String = "Standing task"
) -> [AnyHashable: Any] {
  [
    "aps": [
      "alert": ["title": "Watch AAPL", "body": "AAPL dropped below $180."],
      "category": "assistant_message",
      "thread-id": "assistant-\(conversationID)",
    ],
    "schemaVersion": 1,
    "type": "assistant_message",
    "conversationId": conversationID,
    "messageId": messageID,
    "sourceLabel": sourceLabel,
    "deepLink": deepLink,
  ]
}

// MARK: - Payload parsing

final class AssistantPushPayloadParsingTests: XCTestCase {
  func testBackendPayloadParsesConversationAndMessage() async {
    await Task.yield()
    let route = PushNotificationPayloadParser.parse(
      userInfo: backendPayload(),
      categoryIdentifier: "assistant_message",
      threadIdentifier: "assistant-\(conversationID)"
    )
    XCTAssertEqual(route?.kind, .assistantMessage)
    XCTAssertEqual(route?.conversationID, conversationID)
    XCTAssertEqual(route?.messageID, messageID)
    XCTAssertNil(route?.symbol)
  }

  func testDailyTipPayloadRoutesTheSameWay() async {
    await Task.yield()
    let route = PushNotificationPayloadParser.parse(userInfo: backendPayload(sourceLabel: "Daily tip"))
    XCTAssertEqual(route?.kind, .assistantMessage)
    XCTAssertEqual(route?.conversationID, conversationID)
  }

  func testUppercaseConversationIDIsCanonicalised() async {
    await Task.yield()
    let route = PushNotificationPayloadParser.parse(userInfo: ["type": "assistant_message", "conversationId": conversationID.uppercased()])
    XCTAssertEqual(route?.conversationID, conversationID)
  }

  func testMalformedConversationIDFallsBackToDeepLinkThenThread() async {
    await Task.yield()
    let fromLink = PushNotificationPayloadParser.parse(userInfo: backendPayload(conversationID: "not-a-uuid").merging(
      ["deepLink": "financeplan://assistant/conversations/\(otherConversationID)"]
    ) { $1 })
    XCTAssertEqual(fromLink?.conversationID, otherConversationID)

    let fromThread = PushNotificationPayloadParser.parse(
      userInfo: ["type": "assistant_message", "conversationId": 42],
      threadIdentifier: "assistant-\(otherConversationID)"
    )
    XCTAssertEqual(fromThread?.conversationID, otherConversationID)
  }

  func testMalformedAssistantPayloadStillOpensTheAssistant() async {
    await Task.yield()
    let route = PushNotificationPayloadParser.parse(
      userInfo: ["schemaVersion": 99, "conversationId": "garbage", "deepLink": 7],
      categoryIdentifier: "assistant_message",
      threadIdentifier: "assistant-garbage"
    )
    XCTAssertEqual(route?.kind, .assistantMessage)
    XCTAssertNil(route?.conversationID)
  }

  func testCategoryInApsAloneIdentifiesTheAssistant() async {
    await Task.yield()
    let route = PushNotificationPayloadParser.parse(userInfo: ["aps": ["category": "assistant_message"]])
    XCTAssertEqual(route?.kind, .assistantMessage)
    XCTAssertNil(route?.conversationID)
  }

  func testUnknownTypeWithAssistantCategoryOpensTheAssistant() async {
    await Task.yield()
    let route = PushNotificationPayloadParser.parse(
      userInfo: ["type": "assistant_message_v2"],
      categoryIdentifier: "assistant_message"
    )
    XCTAssertEqual(route?.kind, .assistantMessage)
  }

  func testOtherPushKindsAreUnaffected() async {
    await Task.yield()
    let route = PushNotificationPayloadParser.parse(
      userInfo: ["type": "target_hit", "symbol": "MSFT", "deepLink": "financeplan://stocks/MSFT"],
      categoryIdentifier: "TARGET_ALERT"
    )
    XCTAssertEqual(route?.kind, .targetHit)
    XCTAssertNil(route?.conversationID)
    XCTAssertNil(PushNotificationPayloadParser.parse(userInfo: ["type": "target_hit"]))
  }
}

// MARK: - Deep links

final class AssistantDeepLinkTests: XCTestCase {
  func testConversationLink() async throws {
    await Task.yield()
    let url = try XCTUnwrap(URL(string: "financeplan://assistant/conversations/\(conversationID.uppercased())"))
    XCTAssertEqual(AssistantDeepLink.parse(url), .assistant(conversationID: conversationID))
  }

  func testAppSchemesAreAccepted() async {
    await Task.yield()
    XCTAssertEqual(
      AssistantDeepLink.parse("norviqa://assistant/conversations/\(conversationID)"),
      .assistant(conversationID: conversationID)
    )
    XCTAssertEqual(AssistantDeepLink.parse("norviqa-beta://assistant"), .assistant(conversationID: nil))
  }

  func testBareOrMalformedAssistantLinksOpenTheAssistant() async {
    await Task.yield()
    XCTAssertEqual(AssistantDeepLink.parse("financeplan://assistant"), .assistant(conversationID: nil))
    XCTAssertEqual(AssistantDeepLink.parse("financeplan://assistant/"), .assistant(conversationID: nil))
    XCTAssertEqual(AssistantDeepLink.parse("financeplan://assistant/conversations"), .assistant(conversationID: nil))
    XCTAssertEqual(AssistantDeepLink.parse("financeplan://assistant/conversations/nope"), .assistant(conversationID: nil))
    XCTAssertEqual(AssistantDeepLink.parse("financeplan://assistant/whatever/else"), .assistant(conversationID: nil))
  }

  func testNonAssistantLinksAreIgnored() async {
    await Task.yield()
    XCTAssertNil(AssistantDeepLink.parse("financeplan://stocks/MSFT"))
    XCTAssertNil(AssistantDeepLink.parse("norviqa://oauth/callback?code=1"))
    XCTAssertNil(AssistantDeepLink.parse("https://assistant/conversations/\(conversationID)"))
    XCTAssertNil(AssistantDeepLink.parse(nil as String?))
  }

  func testThreadIdentifier() async {
    await Task.yield()
    XCTAssertEqual(AssistantDeepLink.conversationID(fromThread: "assistant-\(conversationID)"), conversationID)
    XCTAssertNil(AssistantDeepLink.conversationID(fromThread: "assistant-x"))
    XCTAssertNil(AssistantDeepLink.conversationID(fromThread: "earnings-AAPL"))
  }
}

// MARK: - Routing and foreground rules

final class AssistantPushRoutingDecisionTests: XCTestCase {
  private let viewing = AssistantPresence(isVisible: true, conversationID: conversationID)

  func testTapWhileAssistantHiddenPresentsIt() async {
    await Task.yield()
    XCTAssertEqual(
      AssistantPushRouting.openDecision(conversationID: conversationID, presence: .hidden),
      .present(conversationID: conversationID)
    )
    XCTAssertEqual(AssistantPushRouting.openDecision(conversationID: nil, presence: .hidden), .present(conversationID: nil))
  }

  func testTapForTheVisibleThreadRefreshesIt() async {
    await Task.yield()
    XCTAssertEqual(
      AssistantPushRouting.openDecision(conversationID: conversationID, presence: viewing),
      .refreshVisible(conversationID: conversationID)
    )
  }

  func testTapForAnotherThreadSwitchesInPlace() async {
    await Task.yield()
    XCTAssertEqual(
      AssistantPushRouting.openDecision(conversationID: otherConversationID, presence: viewing),
      .switchVisible(conversationID: otherConversationID)
    )
    XCTAssertEqual(AssistantPushRouting.openDecision(conversationID: nil, presence: viewing), .keepVisible)
  }

  func testForegroundBannerUnlessViewingThatThread() async {
    await Task.yield()
    XCTAssertEqual(
      AssistantPushRouting.foregroundDecision(conversationID: conversationID, presence: viewing),
      .refreshThread(conversationID: conversationID)
    )
    XCTAssertEqual(
      AssistantPushRouting.foregroundDecision(conversationID: conversationID.uppercased(), presence: viewing),
      .refreshThread(conversationID: conversationID.uppercased())
    )
    XCTAssertEqual(AssistantPushRouting.foregroundDecision(conversationID: otherConversationID, presence: viewing), .showBanner)
    XCTAssertEqual(AssistantPushRouting.foregroundDecision(conversationID: nil, presence: viewing), .showBanner)
    XCTAssertEqual(AssistantPushRouting.foregroundDecision(conversationID: conversationID, presence: .hidden), .showBanner)
    XCTAssertEqual(
      AssistantPushRouting.foregroundDecision(
        conversationID: conversationID,
        presence: AssistantPresence(isVisible: true, conversationID: nil)
      ),
      .showBanner
    )
  }
}

// MARK: - Coordinator

@MainActor
final class AssistantPushCoordinatorTests: XCTestCase {
  private struct Unused: Error {}

  private final class ServiceStub: PushNotificationsServicing, @unchecked Sendable {
    func registerDevice(deviceToken _: String, apnsEnvironment _: PushAPNSEnvironment, authorizationStatus _: PushAuthorizationStatus) async throws -> PushDeviceRegistrationResponse { throw Unused() }
    func deactivateDevice(deviceToken _: String) async throws {}
    func fetchEarningsPreferences() async throws -> financeplan.EarningsNotificationPreferencesResponse { throw Unused() }
    func updateEarningsPreferences(enabled _: Bool) async throws -> financeplan.EarningsNotificationPreferencesResponse { throw Unused() }
  }

  private final class SessionStub: AuthSessionStoring, @unchecked Sendable {
    var authToken: String = ""
    func setAuthToken(_ value: String) async {
      authToken = value
    }

    var refreshToken: String = ""
    func setRefreshToken(_ value: String) async {
      refreshToken = value
    }

    var authTokenExpiresAt: Date?
    func setAuthTokenExpiresAt(_ value: Date?) async {
      authTokenExpiresAt = value
    }

    var refreshTokenExpiresAt: Date?
    func setRefreshTokenExpiresAt(_ value: Date?) async {
      refreshTokenExpiresAt = value
    }

    var loginIsSignup: Bool = true
    func setLoginIsSignup(_ value: Bool) async {
      loginIsSignup = value
    }

    var currentUserID: String = ""
    func setCurrentUserID(_ value: String) async {
      currentUserID = value
    }

    var currentUsername: String = ""
    func setCurrentUsername(_ value: String) async {
      currentUsername = value
    }

    func store(authResponse _: AuthResponse) async {}
    func clearSession() async {}
    func hasCompletedInitialStockImport(for _: String) async -> Bool {
      false
    }

    func markInitialStockImportCompleted(for _: String) async {}
    func hasCompletedOnboardingQuestionnaire(for _: String) async -> Bool {
      false
    }

    func markOnboardingQuestionnaireCompleted(for _: String) async {}
    func requiresOnboardingQuestionnaire(for _: String) async -> Bool {
      false
    }

    func markOnboardingQuestionnaireRequired(for _: String) async {}
    func markPendingOnboardingAfterSignup(email _: String) async {}
    func hasPendingOnboardingAfterSignup(email _: String) async -> Bool {
      false
    }

    func clearPendingOnboardingAfterSignup(email _: String) async {}
  }

  private func makeCoordinator() -> PushNotificationsCoordinator {
    PushNotificationsCoordinator(
      service: ServiceStub(),
      sessionStore: SessionStub(),
      userDefaults: UserDefaults(suiteName: "AssistantPushCoordinatorTests.\(UUID().uuidString)")!,
      environmentResolver: { .development }
    )
  }

  func testTapQueuesTheAssistantRoute() async {
    await Task.yield()
    let coordinator = makeCoordinator()
    coordinator.handleIncomingRemoteNotification(userInfo: backendPayload())
    let route = coordinator.consumePendingNotificationRoute()
    XCTAssertEqual(route?.kind, .assistantMessage)
    XCTAssertEqual(route?.conversationID, conversationID)
  }

  func testPortfolioActionDoesNotRewriteAnAssistantRoute() async {
    await Task.yield()
    let coordinator = makeCoordinator()
    coordinator.handleIncomingRoute(.assistant(conversationID: conversationID), userAction: .openPortfolio)
    XCTAssertEqual(coordinator.consumePendingNotificationRoute()?.kind, .assistantMessage)
  }

  func testDeepLinkQueuesRouteAndIgnoresOtherURLs() async throws {
    await Task.yield()
    let coordinator = makeCoordinator()
    XCTAssertFalse(coordinator.handleDeepLink(try XCTUnwrap(URL(string: "norviqa://oauth/callback"))))
    XCTAssertNil(coordinator.pendingNotificationRoute)
    XCTAssertTrue(coordinator.handleDeepLink(try XCTUnwrap(URL(string: "financeplan://assistant/conversations/\(conversationID)"))))
    XCTAssertEqual(coordinator.consumePendingNotificationRoute(), .assistant(conversationID: conversationID))
  }

  func testForegroundOptionsFollowWhatIsOnScreen() async {
    await Task.yield()
    let coordinator = makeCoordinator()
    var commands: [AssistantInPlaceCommand] = []
    let subscription = coordinator.assistantCommands.sink { commands.append($0) }
    defer { subscription.cancel() }
    let route = PushNotificationRoute.assistant(conversationID: conversationID)

    XCTAssertEqual(coordinator.foregroundPresentationOptions(for: route), [.banner, .list, .sound])

    let token = UUID()
    coordinator.assistantPresenceChanged(token: token, conversationID: conversationID.uppercased())
    XCTAssertEqual(coordinator.foregroundPresentationOptions(for: route), [])
    XCTAssertEqual(commands, [.refresh(conversationID: conversationID)])

    XCTAssertEqual(
      coordinator.foregroundPresentationOptions(for: .assistant(conversationID: otherConversationID)),
      [.banner, .list, .sound]
    )
    XCTAssertEqual(
      coordinator.foregroundPresentationOptions(for: PushNotificationRoute(kind: .targetHit, symbol: "AAPL")),
      [.banner, .list, .sound]
    )

    coordinator.assistantDidDisappear(token: token)
    XCTAssertEqual(coordinator.foregroundPresentationOptions(for: route), [.banner, .list, .sound])
  }

  func testStaleDisappearDoesNotHideANewerScreen() async {
    await Task.yield()
    let coordinator = makeCoordinator()
    let old = UUID()
    let new = UUID()
    coordinator.assistantPresenceChanged(token: old, conversationID: conversationID)
    coordinator.assistantPresenceChanged(token: new, conversationID: otherConversationID)
    coordinator.assistantDidDisappear(token: old)
    XCTAssertEqual(coordinator.assistantPresence, AssistantPresence(isVisible: true, conversationID: otherConversationID))
  }

  func testResolveOpenSendsInPlaceCommands() async {
    await Task.yield()
    let coordinator = makeCoordinator()
    var commands: [AssistantInPlaceCommand] = []
    let subscription = coordinator.assistantCommands.sink { commands.append($0) }
    defer { subscription.cancel() }

    XCTAssertEqual(coordinator.resolveAssistantOpen(conversationID: conversationID), .present(conversationID: conversationID))
    coordinator.assistantPresenceChanged(token: UUID(), conversationID: conversationID)
    XCTAssertEqual(coordinator.resolveAssistantOpen(conversationID: conversationID), .refreshVisible(conversationID: conversationID))
    XCTAssertEqual(coordinator.resolveAssistantOpen(conversationID: otherConversationID), .switchVisible(conversationID: otherConversationID))
    XCTAssertEqual(commands, [.refresh(conversationID: conversationID), .open(conversationID: otherConversationID)])
  }
}

// MARK: - Assistant screen

@MainActor
final class AssistantPushViewModelTests: XCTestCase {
  private struct Unused: Error {}

  private final class StubAPI: PersistentAssistantServicing, @unchecked Sendable {
    var messagesByConversation: [String: [AIMessageResponse]] = [:]
    var missing: Set<String> = []
    private(set) var fetched: [String] = []

    func conversation(id: String) async throws -> AIConversationResponse {
      fetched.append(id)
      if missing.contains(id) { throw Unused() }
      return AIConversationResponse(id: id, title: "T", messages: messagesByConversation[id] ?? [], createdAt: "2026-09-24T00:00:00Z", updatedAt: "2026-09-24T00:00:00Z")
    }
    func streamTurn(conversationID _: String, content _: String) -> AsyncThrowingStream<PersistentAssistantStreamEvent, Error> {
      AsyncThrowingStream { $0.finish() }
    }
    func confirmAction(id _: String) async throws -> AIConfirmedActionResponse { throw Unused() }
    func cancelAction(id _: String) async throws {}
    func pendingActions() async throws -> [AIPendingActionResponse] { [] }
    func conversations() async throws -> [AIConversationSummaryResponse] {
      ["latest", conversationID].map {
        AIConversationSummaryResponse(id: $0, title: "T", lastMessagePreview: nil, createdAt: "2026-09-24T00:00:00Z", updatedAt: "2026-09-24T00:00:00Z")
      }
    }
    func usage() async throws -> AIAssistantUsageResponse {
      AIAssistantUsageResponse(month: "2026-09", used: 1, limit: nil, remaining: nil, isPro: true)
    }
    func createConversation(title _: String?) async throws -> AIConversationResponse { throw Unused() }
    func deleteConversation(id _: String) async throws {}
    func turn(conversationID _: String, content _: String) async throws -> AIAssistantTurnResponse { throw Unused() }
    func preferences() async throws -> AIAssistantPreferencesResponse {
      AIAssistantPreferencesResponse(proactiveTipsEnabled: true, pushEnabled: true, timezone: "UTC")
    }
    func updatePreferences(_: AIAssistantPreferencesResponse) async throws -> AIAssistantPreferencesResponse { throw Unused() }
    func tips() async throws -> [AITipResponse] { [] }
    func dismissTip(id _: String) async throws {}
    func memos(bookmarked _: Bool?, conversationID _: String?) async throws -> [PositionMemoListItem] { [] }
    func memo(id _: String) async throws -> PositionMemoDetail { throw Unused() }
    func bookmarkMemo(id _: String, bookmarked _: Bool) async throws -> PositionMemoCard { throw Unused() }
    func deleteMemo(id _: String) async throws {}
  }

  private func message(_ id: String) -> AIMessageResponse {
    AIMessageResponse(id: id, conversationId: conversationID, role: .assistant, content: id, createdAt: "2026-09-24T00:00:00Z", origin: .proactive, sourceLabel: "Standing task")
  }

  func testLoadOpensTheConversationFromThePush() async {
    let api = StubAPI()
    let viewModel = PersistentAssistantViewModel(service: api, sleep: { _ in })
    await viewModel.load(preferredConversationID: conversationID)
    XCTAssertEqual(viewModel.activeConversation?.id, conversationID)
  }

  func testLoadFallsBackToLatestWhenThePushedConversationIsGone() async {
    let api = StubAPI()
    api.missing = [conversationID]
    let viewModel = PersistentAssistantViewModel(service: api, sleep: { _ in })
    await viewModel.load(preferredConversationID: conversationID)
    XCTAssertEqual(viewModel.activeConversation?.id, "latest")
    XCTAssertNil(viewModel.errorMessage)
  }

  func testRefreshCommandRefetchesOnlyTheVisibleThread() async throws {
    let api = StubAPI()
    let viewModel = PersistentAssistantViewModel(service: api, sleep: { _ in })
    try await viewModel.selectConversation(id: conversationID)
    api.messagesByConversation[conversationID] = [message("pushed")]

    await viewModel.handle(.refresh(conversationID: otherConversationID))
    XCTAssertEqual(viewModel.activeConversation?.messages.count, 0)

    await viewModel.handle(.refresh(conversationID: conversationID.uppercased()))
    XCTAssertEqual(viewModel.activeConversation?.messages.map(\.id), ["pushed"])
  }

  func testOpenCommandSwitchesConversation() async throws {
    let api = StubAPI()
    let viewModel = PersistentAssistantViewModel(service: api, sleep: { _ in })
    try await viewModel.selectConversation(id: "latest")
    await viewModel.handle(.open(conversationID: conversationID))
    XCTAssertEqual(viewModel.activeConversation?.id, conversationID)
  }
}
