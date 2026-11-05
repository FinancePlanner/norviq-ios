import Foundation
import StockPlanShared
import UIKit
import XCTest
@testable import financeplan

/// Answers every request with a canned status and body, and keeps what it was sent.
private final class ImageTurnURLProtocol: URLProtocol {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var responseBody = Data()
    nonisolated(unsafe) static var request: URLRequest?
    nonisolated(unsafe) static var body = Data()

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.request = request
        Self.body = Self.readBody(of: request)
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// URLSession hands a custom protocol the body as a stream.
    private static func readBody(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

/// One stream per send; records what the view model handed over.
private final class ImageTurnService: PersistentAssistantServicing, @unchecked Sendable {
    struct Unused: Error {}
    struct RefreshFailed: Error {}

    var preferencesResponse = AIAssistantPreferencesResponse(proactiveTipsEnabled: false, pushEnabled: false, timezone: "UTC", imagesEnabled: true)
    var events: [PersistentAssistantStreamEvent] = []
    var streamError: Error?
    var failUsageAfterTurn = false
    /// Runs before the stream ends, for what the user does mid-turn.
    var midTurn: (@Sendable () async -> Void)?
    private(set) var sent: [(content: String, images: [ScreenshotUploadImage], context: AssistantTurnContext?)] = []

    func streamTurn(conversationID _: String, content: String, images: [ScreenshotUploadImage], context: AssistantTurnContext?) -> AsyncThrowingStream<PersistentAssistantStreamEvent, Error> {
        sent.append((content, images, context))
        let events = events
        let streamError = streamError
        let midTurn = midTurn
        return AsyncThrowingStream { continuation in
            Task {
                await midTurn?()
                for event in events { continuation.yield(event) }
                continuation.finish(throwing: streamError)
            }
        }
    }

    func preferences() async throws -> AIAssistantPreferencesResponse { preferencesResponse }
    func usage() async throws -> AIAssistantUsageResponse {
        if failUsageAfterTurn, !sent.isEmpty { throw RefreshFailed() }
        return AIAssistantUsageResponse(month: "2026-11", used: 1, limit: nil, remaining: nil, isPro: true)
    }
    func createConversation(title: String?, bindMessaging _: Bool?) async throws -> AIConversationResponse {
        AIConversationResponse(id: "c1", title: title ?? "", messages: [], createdAt: "2026-11-05T00:00:00Z", updatedAt: "2026-11-05T00:00:00Z")
    }
    func conversations() async throws -> [AIConversationSummaryResponse] { [] }
    func tips() async throws -> [AITipResponse] { [] }
    func pendingActions() async throws -> [AIPendingActionResponse] { [] }

    func conversation(id _: String) async throws -> AIConversationResponse { throw Unused() }
    func deleteConversation(id _: String) async throws { throw Unused() }
    func turn(conversationID _: String, content _: String) async throws -> AIAssistantTurnResponse { throw Unused() }
    func updatePreferences(_: AIAssistantPreferencesResponse) async throws -> AIAssistantPreferencesResponse { throw Unused() }
    func dismissTip(id _: String) async throws { throw Unused() }
    func confirmAction(id _: String) async throws -> AIConfirmedActionResponse { throw Unused() }
    func cancelAction(id _: String) async throws { throw Unused() }
    func memos(bookmarked _: Bool?, conversationID _: String?) async throws -> [PositionMemoListItem] { [] }
    func memo(id _: String) async throws -> PositionMemoDetail { throw Unused() }
    func bookmarkMemo(id _: String, bookmarked _: Bool) async throws -> PositionMemoCard { throw Unused() }
    func deleteMemo(id _: String) async throws { throw Unused() }
}

/// One part of a multipart body, read back from the bytes sent.
private struct SentPart {
    let name: String
    let filename: String?
    let contentType: String?
    let body: Data
}

private func parts(of body: Data, boundary: String) throws -> [SentPart] {
    // Latin-1 maps bytes one to one, so offsets found in the string hold in the data.
    let text = try XCTUnwrap(String(data: body, encoding: .isoLatin1))
    XCTAssertTrue(text.hasSuffix("--\(boundary)--\r\n"), "closing boundary missing")
    return try text.components(separatedBy: "--\(boundary)").dropFirst().dropLast().map { raw in
        // "\r\n" is one Character in Swift, so this drops both bytes.
        let section = raw.hasPrefix("\r\n") ? String(raw.dropFirst()) : raw
        let divider = try XCTUnwrap(section.range(of: "\r\n\r\n"))
        let headers = section[..<divider.lowerBound].components(separatedBy: "\r\n")
        var value = String(section[divider.upperBound...])
        XCTAssertTrue(value.hasSuffix("\r\n"), "part must end in CRLF")
        value.removeLast() // the one Character "\r\n"
        let disposition = try XCTUnwrap(headers.first { $0.hasPrefix("Content-Disposition:") })
        func parameter(_ key: String) -> String? {
            guard let start = disposition.range(of: "\(key)=\"") else { return nil }
            return String(disposition[start.upperBound...].prefix { $0 != "\"" })
        }
        return SentPart(
            name: try XCTUnwrap(parameter("name")),
            filename: parameter("filename"),
            contentType: headers.first { $0.hasPrefix("Content-Type:") }.map { String($0.dropFirst("Content-Type: ".count)) },
            body: try XCTUnwrap(value.data(using: .isoLatin1))
        )
    }
}

private func jpeg(width: CGFloat = 10, height: CGFloat = 10) -> Data {
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        .jpegData(withCompressionQuality: 0.8) { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
}

private func sources(_ count: Int) -> [@Sendable () async -> Data?] {
    let data = jpeg()
    return Array(repeating: { data }, count: count)
}

private let turnAnswered: AIAssistantTurnResponse = {
    let json = #"""
    {"kind":"message","conversationId":"c1","message":{"id":"m1","conversationId":"c1","role":"assistant","content":"It shows a fill.","createdAt":"2026-11-05T00:00:00Z"}}
    """#
    return try! JSONDecoder().decode(AIAssistantTurnResponse.self, from: Data(json.utf8))
}()

@MainActor
final class AssistantImageTurnTests: XCTestCase {
    private static let privacyNote = "Q sends your messages and the financial context it needs (portfolio, spending, budgets) to Anthropic and OpenRouter to write replies. An image you attach to Q is sent only for that one message, to Anthropic and OpenRouter (or to your own provider if you connected a working key of your own). Norviq does not store the image. What Q reads from it, such as its reply or trades you save, is kept like any other message. Your data is not used to train models by Norviq's providers; your name and email are not sent, unless they are visible in an image you attach or import. Conversations are encrypted and retained for 30 days."

    private let sse = Data("event: started\ndata: {}\n\nevent: done\ndata: {}\n\n".utf8)
    private let context = AssistantTurnContext(screen: nil, timeZone: "Europe/Lisbon", locale: "pt-PT", inputMode: .text)

    override func setUp() async throws {
        ImageTurnURLProtocol.status = 200
        ImageTurnURLProtocol.responseBody = sse
        ImageTurnURLProtocol.request = nil
        ImageTurnURLProtocol.body = Data()
    }

    private func makeClient() -> AssistantStreamClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ImageTurnURLProtocol.self]
        return AssistantStreamClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: URLSession(configuration: configuration),
            authTokenProvider: { "token" }
        )
    }

    private func drain(_ stream: AsyncThrowingStream<PersistentAssistantStreamEvent, Error>) async throws {
        for try await _ in stream {}
    }

    /// The failure a status turns into, in the words the user reads.
    private func failure(
        status: Int,
        body: String = "",
        images: [ScreenshotUploadImage] = [ScreenshotUploadImage(data: Data([0xFF, 0xD8, 0xFF]))]
    ) async -> AssistantStreamClient.Failure? {
        ImageTurnURLProtocol.status = status
        ImageTurnURLProtocol.responseBody = Data(body.utf8)
        do {
            try await drain(makeClient().streamTurn(conversationID: "c1", content: "Hi", images: images, context: nil))
            return nil
        } catch {
            return error as? AssistantStreamClient.Failure
        }
    }

    private func loadedViewModel(_ service: ImageTurnService) async -> PersistentAssistantViewModel {
        let viewModel = PersistentAssistantViewModel(service: service, sleep: { _ in })
        await viewModel.load()
        return viewModel
    }

    private func preferences(from json: String) throws -> AIAssistantPreferencesResponse {
        try JSONDecoder().decode(AIAssistantPreferencesResponse.self, from: Data(json.utf8))
    }

    // MARK: Request

    func testMultipartRequestHasContentAndImageParts() async throws {
        let first = ScreenshotUploadImage(data: Data([0xFF, 0xD8, 0xFF, 0x00, 0x0D, 0x0A, 0x01]))
        let second = ScreenshotUploadImage(data: Data([0xFF, 0xD8, 0xFF, 0x02]), contentType: "image/png", filename: "fills.png")

        try await drain(makeClient().streamTurn(conversationID: "c1", content: "Which fills?", images: [first, second], context: context))

        let request = try XCTUnwrap(ImageTurnURLProtocol.request)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/v1/ai/assistant/conversations/c1/stream")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "text/event-stream")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        let contentType = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="), contentType)
        let boundary = String(contentType.dropFirst("multipart/form-data; boundary=".count))
        XCTAssertFalse(boundary.isEmpty)

        let sent = try parts(of: ImageTurnURLProtocol.body, boundary: boundary)
        XCTAssertEqual(sent.map(\.name), ["content", "context", "image", "image"])
        XCTAssertEqual(String(data: sent[0].body, encoding: .utf8), "Which fills?")
        XCTAssertNil(sent[0].filename)
        let sentContext = try JSONDecoder().decode(AssistantTurnContext.self, from: sent[1].body)
        XCTAssertEqual(sentContext, context)
        XCTAssertEqual(sent[2].body, first.data)
        XCTAssertEqual(sent[2].contentType, "image/jpeg")
        // The backend only counts a part with a filename as an image.
        XCTAssertEqual(sent[2].filename, "image-1.jpg")
        XCTAssertEqual(sent[3].body, second.data)
        XCTAssertEqual(sent[3].contentType, "image/png")
        XCTAssertEqual(sent[3].filename, "fills.png")
    }

    func testMultipartWithNoTextSendsEmptyContentAndNoContextPart() async throws {
        let image = ScreenshotUploadImage(data: Data([0xFF, 0xD8, 0xFF]))

        try await drain(makeClient().streamTurn(conversationID: "c1", content: "", images: [image], context: nil))

        let contentType = try XCTUnwrap(ImageTurnURLProtocol.request?.value(forHTTPHeaderField: "Content-Type"))
        let sent = try parts(of: ImageTurnURLProtocol.body, boundary: String(contentType.dropFirst("multipart/form-data; boundary=".count)))
        XCTAssertEqual(sent.map(\.name), ["content", "image"])
        XCTAssertEqual(sent[0].body, Data())
    }

    func testNoImagesKeepsJSONBody() async throws {
        try await drain(makeClient().streamTurn(conversationID: "c1", content: "Hi", images: [], context: nil))

        let request = try XCTUnwrap(ImageTurnURLProtocol.request)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "text/event-stream")
        XCTAssertEqual(String(data: ImageTurnURLProtocol.body, encoding: .utf8), #"{"content":"Hi"}"#)

        try await drain(makeClient().streamTurn(conversationID: "c1", content: "Hi", images: [], context: context))
        XCTAssertEqual(ImageTurnURLProtocol.request?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        // JSONEncoder does not promise a key order, so compare what the bytes say.
        let sent = try XCTUnwrap(JSONSerialization.jsonObject(with: ImageTurnURLProtocol.body) as? NSDictionary)
        let expected = try XCTUnwrap(
            JSONSerialization.jsonObject(with: AssistantStreamClient.turnBody(content: "Hi", context: context)) as? NSDictionary
        )
        XCTAssertEqual(sent, expected)
    }

    func testTextOnlyCallSendsNoImages() async throws {
        let service = ImageTurnService()
        for try await _ in service.streamTurn(conversationID: "c1", content: "Hi", context: context) {}
        XCTAssertEqual(service.sent.first?.images, [])
    }

    // MARK: Statuses

    func test413SaysTheImageIsTooLarge() async {
        let failure = await failure(status: 413)
        XCTAssertEqual(failure?.errorDescription, "That image is too large.")
    }

    func test429OnImageTurnAsksToWaitAMinute() async {
        let failure = await failure(status: 429)
        XCTAssertEqual(failure?.errorDescription, "Too many requests. Wait a minute and try again.")
    }

    func test503ShowsTheBackendsReason() async {
        let body = #"{"error":true,"reason":"Too many large images right now. Try again in a moment."}"#
        let failure = await failure(status: 503, body: body)
        XCTAssertEqual(failure?.errorDescription, "Too many large images right now. Try again in a moment.")
    }

    func test503WithoutAJSONReasonStaysGeneric() async {
        let proxyPage = await failure(status: 503, body: "<html>Bad gateway</html>")
        XCTAssertEqual(proxyPage?.errorDescription, "The assistant is unavailable (503). Please try again.")
        let noReason = await failure(status: 503, body: #"{"error":true}"#)
        XCTAssertEqual(noReason?.errorDescription, "The assistant is unavailable (503). Please try again.")
    }

    func testTextTurnStatusesKeepTheirMessages() async {
        let tooMany = await failure(status: 429, images: [])
        XCTAssertEqual(tooMany?.errorDescription, "You've reached today's assistant limit. Try again tomorrow.")
        let unavailable = await failure(status: 503, body: #"{"reason":"Busy"}"#, images: [])
        XCTAssertEqual(unavailable?.errorDescription, "The assistant is unavailable (503). Please try again.")
    }

    // MARK: Composer

    func testSendEnabledWithImageAndNoText() async {
        let service = ImageTurnService()
        service.events = [.started, .turn(turnAnswered), .done]
        let viewModel = await loadedViewModel(service)
        XCTAssertFalse(viewModel.canSend)

        await viewModel.addAttachments(sources(1))

        XCTAssertTrue(viewModel.canSend)
        await viewModel.send()
        XCTAssertEqual(service.sent.count, 1)
        XCTAssertEqual(service.sent[0].content, "")
        XCTAssertEqual(service.sent[0].images.count, 1)
        XCTAssertNotNil(service.sent[0].context)
        XCTAssertEqual(viewModel.attachments, [])
        XCTAssertNil(viewModel.errorMessage)
        // What the server stores for this turn, so a reload changes nothing.
        XCTAssertEqual(viewModel.activeConversation?.messages.first?.content, "What's in this image? [image attached]")
    }

    func testImageTurnWithTextShowsTheMarker() async {
        let service = ImageTurnService()
        service.events = [.turn(turnAnswered), .done]
        let viewModel = await loadedViewModel(service)
        viewModel.draft = "  Which fills?  "
        await viewModel.addAttachments(sources(2))

        await viewModel.send()

        XCTAssertEqual(service.sent[0].content, "Which fills?")
        XCTAssertEqual(service.sent[0].images.count, 2)
        XCTAssertEqual(viewModel.activeConversation?.messages.first?.content, "Which fills? [image attached]")
    }

    func testTextTurnStaysAsItWas() async {
        let service = ImageTurnService()
        service.events = [.turn(turnAnswered), .done]
        let viewModel = await loadedViewModel(service)
        viewModel.draft = "Hi"
        XCTAssertTrue(viewModel.canSend)

        await viewModel.send()

        XCTAssertEqual(service.sent[0].content, "Hi")
        XCTAssertEqual(service.sent[0].images, [])
        XCTAssertEqual(viewModel.activeConversation?.messages.first?.content, "Hi")
    }

    func testMaxThreeAttachments() async {
        let viewModel = await loadedViewModel(ImageTurnService())

        await viewModel.addAttachments(sources(4))
        XCTAssertEqual(viewModel.attachments.count, 3)
        XCTAssertEqual(viewModel.attachmentRoom, 0)
        XCTAssertEqual(viewModel.attachmentNotice, "Attach up to 3 images.")

        await viewModel.addAttachments(sources(1))
        XCTAssertEqual(viewModel.attachments.count, 3)
    }

    func testAttachmentRoomCountsWhatIsAttached() async {
        let viewModel = await loadedViewModel(ImageTurnService())
        XCTAssertEqual(viewModel.attachmentRoom, 3)
        await viewModel.addAttachments(sources(2))
        XCTAssertEqual(viewModel.attachmentRoom, 1)
        XCTAssertNil(viewModel.attachmentNotice)
    }

    func testRemoveAttachmentTakesOnlyThatOne() async throws {
        let viewModel = await loadedViewModel(ImageTurnService())
        await viewModel.addAttachments(sources(3))
        let kept = [viewModel.attachments[0].id, viewModel.attachments[2].id]

        viewModel.removeAttachment(id: viewModel.attachments[1].id)

        XCTAssertEqual(viewModel.attachments.map(\.id), kept)
    }

    func testUnreadableImageIsSkippedWithANotice() async {
        let viewModel = await loadedViewModel(ImageTurnService())
        let good = jpeg()

        await viewModel.addAttachments([{ Data("not an image".utf8) }, { nil }, { good }])

        XCTAssertEqual(viewModel.attachments.count, 1)
        XCTAssertEqual(viewModel.attachmentNotice, "This image could not be attached. Try another one.")
    }

    func testCannotSendWhileAnImageIsBeingPrepared() async {
        let service = ImageTurnService()
        let viewModel = await loadedViewModel(service)
        viewModel.draft = "Hi"
        let (gate, open) = AsyncStream.makeStream(of: Data.self)

        let adding = Task {
            await viewModel.addAttachments([{
                var iterator = gate.makeAsyncIterator()
                return await iterator.next()
            }])
        }
        while viewModel.preparingAttachmentCount == 0 { await Task.yield() }

        XCTAssertFalse(viewModel.canSend)
        XCTAssertEqual(viewModel.attachmentRoom, 2)
        await viewModel.send()
        XCTAssertTrue(service.sent.isEmpty)
        XCTAssertEqual(viewModel.draft, "Hi")

        open.yield(jpeg())
        await adding.value
        XCTAssertEqual(viewModel.preparingAttachmentCount, 0)
        XCTAssertTrue(viewModel.canSend)
    }

    func testLocalCommandKeepsAttachments() async {
        let service = ImageTurnService()
        let viewModel = await loadedViewModel(service)
        await viewModel.addAttachments(sources(1))
        viewModel.draft = "/help"

        await viewModel.send()

        XCTAssertTrue(service.sent.isEmpty)
        XCTAssertEqual(viewModel.attachments.count, 1)
        XCTAssertEqual(viewModel.activeConversation?.messages.first?.content, "/help")
    }

    // MARK: Restoring the composer

    func testImageRejectedFrameShowsItsMessageAndRestores() async {
        let service = ImageTurnService()
        service.events = [.started, .error("Only JPEG, PNG, WebP and GIF images are supported.", code: "image_rejected"), .done]
        let viewModel = await loadedViewModel(service)
        viewModel.draft = "Which fills?"
        await viewModel.addAttachments(sources(2))
        let attached = viewModel.attachments

        await viewModel.send()

        XCTAssertEqual(viewModel.errorMessage, "Only JPEG, PNG, WebP and GIF images are supported.")
        XCTAssertEqual(viewModel.draft, "Which fills?")
        XCTAssertEqual(viewModel.attachments.map(\.id), attached.map(\.id))
        XCTAssertEqual(viewModel.activeConversation?.messages, [])
    }

    func testConsentFrameRestores() async {
        let service = ImageTurnService()
        service.events = [.error("Allow AI data sharing to use the assistant.", code: "ai_consent_required"), .done]
        let viewModel = await loadedViewModel(service)
        await viewModel.addAttachments(sources(1))

        await viewModel.send()

        XCTAssertEqual(viewModel.attachments.count, 1)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testUpgradeFrameShowsPaywallAndSaysWhyAndRestores() async {
        let service = ImageTurnService()
        service.events = [.error("Screenshot import requires Pro.", code: "upgrade_required"), .done]
        let viewModel = await loadedViewModel(service)
        viewModel.draft = "Which fills?"
        await viewModel.addAttachments(sources(1))

        await viewModel.send()

        XCTAssertTrue(viewModel.isPaywallRequested)
        XCTAssertEqual(viewModel.attachmentNotice, "Attaching images is part of Pro. Upgrade to use it.")
        XCTAssertEqual(viewModel.draft, "Which fills?")
        XCTAssertEqual(viewModel.attachments.count, 1)
    }

    func testUpgradeStatusOnImageTurnSaysWhy() async {
        let service = ImageTurnService()
        service.streamError = AssistantStreamClient.Failure.upgradeRequired
        let viewModel = await loadedViewModel(service)
        await viewModel.addAttachments(sources(1))

        await viewModel.send()

        XCTAssertTrue(viewModel.isPaywallRequested)
        XCTAssertEqual(viewModel.attachmentNotice, "Attaching images is part of Pro. Upgrade to use it.")
    }

    func testQuotaFrameDoesNotBlameImages() async {
        let service = ImageTurnService()
        service.events = [.error("Out of turns", code: "quota_exhausted"), .done]
        let viewModel = await loadedViewModel(service)
        await viewModel.addAttachments(sources(1))

        await viewModel.send()

        XCTAssertTrue(viewModel.isPaywallRequested)
        XCTAssertNil(viewModel.attachmentNotice)
        XCTAssertEqual(viewModel.attachments.count, 1)
    }

    func testFailedStatusRestores() async {
        let service = ImageTurnService()
        service.streamError = AssistantStreamClient.Failure.imageTooLarge
        let viewModel = await loadedViewModel(service)
        viewModel.draft = "Which fills?"
        await viewModel.addAttachments(sources(3))

        await viewModel.send()

        XCTAssertEqual(viewModel.errorMessage, "That image is too large.")
        XCTAssertEqual(viewModel.draft, "Which fills?")
        XCTAssertEqual(viewModel.attachments.count, 3)
        XCTAssertEqual(viewModel.activeConversation?.messages, [])
    }

    func testStreamWithNoTurnRestores() async {
        let service = ImageTurnService()
        service.events = [.started, .done]
        let viewModel = await loadedViewModel(service)
        await viewModel.addAttachments(sources(1))

        await viewModel.send()

        XCTAssertEqual(viewModel.attachments.count, 1)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testTextTypedDuringTheTurnSurvivesARestore() async {
        let service = ImageTurnService()
        service.events = [.error("Nope", code: "image_rejected"), .done]
        let viewModel = await loadedViewModel(service)
        service.midTurn = { @MainActor in viewModel.draft = "and this" }
        viewModel.draft = "Which fills?"
        await viewModel.addAttachments(sources(1))

        await viewModel.send()

        XCTAssertEqual(viewModel.draft, "Which fills?\nand this")
    }

    /// As web: once the turn frame arrived the message is stored, and sending
    /// the images again could only repeat it.
    func testRefreshFailingAfterTheTurnLandedRestoresNothing() async {
        let service = ImageTurnService()
        service.events = [.turn(turnAnswered), .done]
        service.failUsageAfterTurn = true
        let viewModel = await loadedViewModel(service)
        viewModel.draft = "Which fills?"
        await viewModel.addAttachments(sources(1))

        await viewModel.send()

        XCTAssertEqual(viewModel.attachments, [])
        XCTAssertEqual(viewModel.draft, "")
        XCTAssertEqual(viewModel.activeConversation?.messages.map(\.content), ["Which fills? [image attached]", "It shows a fill."])
    }

    func testTextTurnFailureStillRestoresDraft() async {
        let service = ImageTurnService()
        service.events = [.error("Nope"), .done]
        let viewModel = await loadedViewModel(service)
        viewModel.draft = "Hi"

        await viewModel.send()

        XCTAssertEqual(viewModel.draft, "Hi")
        XCTAssertEqual(viewModel.errorMessage, "Nope")
        XCTAssertNil(viewModel.attachmentNotice)
    }

    // MARK: Flag

    func testImagesEnabledAbsentMeansFalse() async throws {
        let absent = try preferences(from: #"{"proactiveTipsEnabled":true,"pushEnabled":false,"timezone":"UTC"}"#)
        XCTAssertNil(absent.imagesEnabled)

        let service = ImageTurnService()
        service.preferencesResponse = absent
        let viewModel = PersistentAssistantViewModel(service: service, sleep: { _ in })
        XCTAssertFalse(viewModel.imagesEnabled, "before preferences load")
        await viewModel.load()
        XCTAssertFalse(viewModel.imagesEnabled)
    }

    func testImagesEnabledReadFromPreferences() async throws {
        let service = ImageTurnService()
        service.preferencesResponse = try preferences(from: #"{"proactiveTipsEnabled":true,"pushEnabled":false,"timezone":"UTC","imagesEnabled":true}"#)
        let viewModel = await loadedViewModel(service)
        XCTAssertTrue(viewModel.imagesEnabled)

        service.preferencesResponse = try preferences(from: #"{"proactiveTipsEnabled":true,"pushEnabled":false,"timezone":"UTC","imagesEnabled":false}"#)
        let off = await loadedViewModel(service)
        XCTAssertFalse(off.imagesEnabled)
    }

    func testPreferencesUpdateBodyDoesNotGainTheField() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let payload = AIAssistantPreferencesResponse(proactiveTipsEnabled: true, pushEnabled: false, timezone: "UTC")
        XCTAssertEqual(
            String(data: try encoder.encode(payload), encoding: .utf8),
            #"{"proactiveTipsEnabled":true,"pushEnabled":false,"timezone":"UTC"}"#
        )
    }

    // MARK: Preparing images

    func testPreparerHonoursATighterCap() {
        let image = jpeg(width: 200, height: 200)
        XCTAssertNotNil(UploadImagePreparer.prepare(image, maxBytes: image.count * 4))
        XCTAssertNil(UploadImagePreparer.prepare(image, maxBytes: 10))
        XCTAssertNotNil(UploadImagePreparer.prepare(image), "the default cap stays")
    }

    func testAttachmentCapMatchesTheBackend() {
        XCTAssertEqual(PersistentAssistantViewModel.maxAttachments, 3)
        XCTAssertEqual(PersistentAssistantViewModel.maxAttachmentBytes, 5 << 20)
    }

    func testAttachedImageIsShrunkToTheLongEdge() async throws {
        let viewModel = await loadedViewModel(ImageTurnService())
        let large = jpeg(width: 3000, height: 1000)

        await viewModel.addAttachments([{ large }])

        let attached = try XCTUnwrap(viewModel.attachments.first)
        XCTAssertEqual(attached.contentType, "image/jpeg")
        let decoded = try XCTUnwrap(UIImage(data: attached.data))
        XCTAssertEqual(decoded.size.width * decoded.scale, 1568, accuracy: 1)
    }

    // MARK: Copy

    func testNewStringsHavePortuguese() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("financeplan/Localizable.xcstrings")
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        let keys = [
            "Attach images", "Attached image", "Preparing image", "Remove image",
            "Attach up to %lld images.", "This image could not be attached. Try another one.",
            "Attaching images is part of Pro. Upgrade to use it.",
            "That image is too large.", "Too many requests. Wait a minute and try again.",
            Self.privacyNote,
            "Images you attach to the assistant are sent too, for that message only.",
            "Not used to train AI models by Norviq's providers",
            "Your name and email are not sent, unless they are visible in an image you attach or import"
        ]
        for key in keys {
            let entry = strings[key] as? [String: Any]
            let localizations = entry?["localizations"] as? [String: Any]
            let portuguese = (localizations?["pt-PT"] as? [String: Any])?["stringUnit"] as? [String: Any]
            XCTAssertEqual(portuguese?["state"] as? String, "translated", "missing pt-PT for \(key)")
            XCTAssertFalse((portuguese?["value"] as? String ?? "").isEmpty, "empty pt-PT for \(key)")
        }
        XCTAssertFalse(strings.keys.contains { $0.contains("Financial changes always require confirmation") })
        XCTAssertNil(strings["Not used to train AI models"], "replaced by the wording naming Norviq's providers")
        XCTAssertNil(strings["Your name and email are not sent"], "replaced by the wording that excepts images")
    }

    func testViewShowsThePrivacyNoteWithoutTheFalseLine() throws {
        let viewURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("financeplan/Features/Assistant/PersistentAssistantView.swift")
        let source = try String(contentsOf: viewURL, encoding: .utf8)
        XCTAssertTrue(source.contains(Self.privacyNote))
        XCTAssertFalse(source.contains("always require confirmation"))
    }

    func testConsentSheetSaysImagesAreSent() throws {
        let sheetURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("financeplan/Features/AIConsent/AIConsentSheet.swift")
        let source = try String(contentsOf: sheetURL, encoding: .utf8)
        XCTAssertTrue(source.contains("Images you attach to the assistant are sent too, for that message only."))
        XCTAssertTrue(source.contains("Not used to train AI models by Norviq's providers"))
        XCTAssertTrue(source.contains("Your name and email are not sent, unless they are visible in an image you attach or import"))
    }
}
