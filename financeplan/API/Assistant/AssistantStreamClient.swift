//
//  AssistantStreamClient.swift
//  financeplan
//
//  Streams the in-app assistant's Server-Sent Events response from
//  POST /v1/ai/chat. BaseHTTPClient is buffered and cannot stream, so this is a
//  dedicated client built on URLSession.bytes. It still follows the app's
//  conventions: injected baseURL + authTokenProvider.
//

import Foundation
import StockPlanShared

/// An event emitted by the assistant during a turn.
enum AssistantStreamEvent: Sendable, Equatable {
    /// A tool is running (e.g. "Adding expense…").
    case tool(String)
    /// The final assistant message (Markdown).
    case message(String)
    /// The turn is complete.
    case done
}

struct AssistantChatMessageDTO: Codable, Sendable {
    let role: String
    let content: String
}

struct AssistantChatRequestDTO: Codable, Sendable {
    let messages: [AssistantChatMessageDTO]
}

private struct PersistentAssistantTurnRequestDTO: Codable, Sendable {
    let content: String
    let context: AssistantTurnContext?
}

enum PersistentAssistantStreamEvent: Sendable {
    case started
    /// A tool is running; the label is the server's activity line
    /// (e.g. "Adding expense…"). Older backends never send it.
    case tool(String)
    case turn(AIAssistantTurnResponse)
    /// `code` is absent on older backends and on failures with no special
    /// handling. Known values: `ai_consent_required`, `quota_exhausted`,
    /// `upgrade_required`, `conversation_not_found`, `user_credential_rejected`.
    case error(String, code: String? = nil)
    case done
}

struct AssistantStreamClient: Sendable {
    enum Failure: LocalizedError {
        case invalidResponse
        case unauthorized
        case upgradeRequired
        case rateLimited
        case aiConsentRequired
        case server(Int)
        case imageTooLarge
        case imageTurnsRateLimited
        case imagesBusy(String)
        case largeImagesBusy

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "The assistant returned an unexpected response."
            case .unauthorized: "Please sign in again to use the assistant."
            case .upgradeRequired: "The assistant requires Norviq Pro."
            case .rateLimited: "You've reached today's assistant limit. Try again tomorrow."
            case .aiConsentRequired: "Allow AI data sharing to use the assistant."
            case let .server(code): "The assistant is unavailable (\(code)). Please try again."
            case .imageTooLarge: String(localized: "That image is too large.")
            case .imageTurnsRateLimited: String(localized: "Too many requests. Wait a minute and try again.")
            case let .imagesBusy(reason): reason
            case .largeImagesBusy: String(localized: "Too many large images right now. Try again in a moment.")
            }
        }
    }

    let baseURL: URL
    let session: URLSession
    let authTokenProvider: @Sendable () async -> String?

    init(
        baseURL: URL,
        session: URLSession = .shared,
        authTokenProvider: @escaping @Sendable () async -> String? = { nil }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authTokenProvider = authTokenProvider
    }

    private static func smallBody(_ bytes: URLSession.AsyncBytes) async throws -> Data {
        var body = Data()
        for try await byte in bytes {
            body.append(byte)
            if body.count >= 4_096 { break }
        }
        return body
    }

    /// Reads a small error body to tell "allow AI first" apart from "upgrade".
    private static func isConsentRequired(_ bytes: URLSession.AsyncBytes) async throws -> Bool {
        AIConsentRequired.matches(statusCode: 403, body: try await smallBody(bytes))
    }

    private static let largeImagesBusyReason = "Too many large images right now. Try again in a moment."

    /// Statuses an image turn meets before its stream opens: the body cap, the
    /// image rate limit (per minute, unlike the daily limit a text turn's 429
    /// reports) and the large-image slots. A 503 with no JSON `reason` came from
    /// something other than the backend, so it stays the generic failure.
    private static func imageTurnFailure(status: Int, bytes: URLSession.AsyncBytes) async throws -> Failure? {
        switch status {
        case 413:
            return .imageTooLarge
        case 429:
            return .imageTurnsRateLimited
        case 503:
            let body = String(decoding: try await smallBody(bytes), as: UTF8.self)
            guard let reason = field("reason", in: body)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !reason.isEmpty
            else { return nil }
            // The backend's only busy reason (largeTurnsBusy in images.go) is
            // English; say it in the app's language.
            if reason == largeImagesBusyReason { return .largeImagesBusy }
            return .imagesBusy(String(reason.prefix(300)))
        default:
            return nil
        }
    }

    /// Sends the conversation and returns an async stream of assistant events.
    func stream(messages: [AssistantChatMessageDTO]) -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: baseURL.appendingPathComponent("v1/ai/chat"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    if let token = await authTokenProvider() {
                        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }
                    request.httpBody = try JSONEncoder().encode(AssistantChatRequestDTO(messages: messages))

                    let (bytes, response) = try await session.bytes(for: ClientCapabilities.applied(to: request))
                    guard let http = response as? HTTPURLResponse else {
                        throw Failure.invalidResponse
                    }
                    if http.statusCode == 403, try await Self.isConsentRequired(bytes) {
                        AIConsentRequired.post()
                        throw Failure.aiConsentRequired
                    }
                    switch http.statusCode {
                    case 200: break
                    case 401: throw Failure.unauthorized
                    case 402, 403: throw Failure.upgradeRequired
                    case 429: throw Failure.rateLimited
                    default: throw Failure.server(http.statusCode)
                    }

                    var event = "message"
                    for try await line in bytes.lines {
                        if line.isEmpty { event = "message"; continue }
                        if line.hasPrefix("event:") {
                            event = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            let json = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                            if let parsed = Self.decode(event: event, json: json) {
                                continuation.yield(parsed)
                            }
                        }
                    }
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Streams a persisted assistant turn. The backend writes the user and
    /// assistant messages before emitting the final turn event. A turn with
    /// images goes as a multipart form; any other stays JSON, because a multipart
    /// request spends the user's image rate budget even with no image in it.
    func streamTurn(
        conversationID: String,
        content: String,
        images: [ScreenshotUploadImage] = [],
        context: AssistantTurnContext? = nil
    ) -> AsyncThrowingStream<PersistentAssistantStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let path = "v1/ai/assistant/conversations/\(conversationID)/stream"
                    var request = URLRequest(url: baseURL.appendingPathComponent(path))
                    request.httpMethod = "POST"
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    if let token = await authTokenProvider() {
                        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }
                    if images.isEmpty {
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        request.httpBody = try Self.turnBody(content: content, context: context)
                    } else {
                        let form = try Self.imageTurnForm(content: content, images: images, context: context)
                        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
                        request.httpBody = form.finalizedData()
                    }

                    let (bytes, response) = try await session.bytes(for: ClientCapabilities.applied(to: request))
                    guard let http = response as? HTTPURLResponse else {
                        throw Failure.invalidResponse
                    }
                    if http.statusCode == 403, try await Self.isConsentRequired(bytes) {
                        AIConsentRequired.post()
                        throw Failure.aiConsentRequired
                    }
                    if !images.isEmpty, let failure = try await Self.imageTurnFailure(status: http.statusCode, bytes: bytes) {
                        throw failure
                    }
                    switch http.statusCode {
                    case 200: break
                    case 401: throw Failure.unauthorized
                    case 402, 403: throw Failure.upgradeRequired
                    case 429: throw Failure.rateLimited
                    default: throw Failure.server(http.statusCode)
                    }

                    var event = "message"
                    for try await line in bytes.lines {
                        if line.isEmpty {
                            event = "message"
                            continue
                        }
                        if line.hasPrefix("event:") {
                            event = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                            continue
                        }
                        guard line.hasPrefix("data:") else { continue }
                        let json = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        if let parsed = try Self.decodePersistent(event: event, json: json) {
                            continuation.yield(parsed)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func turnBody(content: String, context: AssistantTurnContext?) throws -> Data {
        try JSONEncoder().encode(PersistentAssistantTurnRequestDTO(content: content, context: context))
    }

    /// The backend counts a part as an image only if it has a filename, and
    /// reads `context` as the same JSON a text turn's body carries.
    private static func imageTurnForm(
        content: String,
        images: [ScreenshotUploadImage],
        context: AssistantTurnContext?
    ) throws -> MultipartFormBody {
        var form = MultipartFormBody()
        form.addField(name: "content", value: content)
        if let context {
            form.addField(name: "context", value: String(decoding: try JSONEncoder().encode(context), as: UTF8.self))
        }
        for (index, image) in images.enumerated() {
            form.addFile(
                name: "image",
                filename: image.filename ?? "image-\(index + 1).jpg",
                contentType: image.contentType,
                data: image.data
            )
        }
        return form
    }

    /// Maps one SSE frame of the persisted-turn stream. Frames this client
    /// does not know, and `tool` frames without a label, return nil so a newer
    /// backend never breaks an older app (and vice versa).
    static func decodePersistent(event: String, json: String) throws -> PersistentAssistantStreamEvent? {
        switch event {
        case "started":
            return .started
        case "tool":
            guard let label = field("label", in: json) else { return nil }
            return .tool(label)
        case "turn":
            guard let data = json.data(using: .utf8) else { throw Failure.invalidResponse }
            return .turn(try JSONDecoder().decode(AIAssistantTurnResponse.self, from: data))
        case "error":
            return .error(field("message", in: json) ?? "The assistant could not complete this turn.", code: field("code", in: json))
        case "done":
            return .done
        default:
            return nil
        }
    }

    private static func decode(event: String, json: String) -> AssistantStreamEvent? {
        switch event {
        case "tool":
            guard let label = field("label", in: json) else { return nil }
            return .tool(label)
        case "message":
            guard let content = field("content", in: json) else { return nil }
            return .message(content)
        case "done":
            return .done
        default:
            return nil
        }
    }

    private static func field(_ key: String, in json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return obj[key] as? String
    }
}
