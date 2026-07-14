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
}

enum PersistentAssistantStreamEvent: Sendable {
    case started
    case turn(AIAssistantTurnResponse)
    case error(String)
    case done
}

struct AssistantStreamClient: Sendable {
    enum Failure: LocalizedError {
        case invalidResponse
        case unauthorized
        case upgradeRequired
        case rateLimited
        case server(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "The assistant returned an unexpected response."
            case .unauthorized: "Please sign in again to use the assistant."
            case .upgradeRequired: "The assistant requires Norviq Pro."
            case .rateLimited: "You've reached today's assistant limit. Try again tomorrow."
            case let .server(code): "The assistant is unavailable (\(code)). Please try again."
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

                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw Failure.invalidResponse
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
    /// assistant messages before emitting the final turn event.
    func streamTurn(
        conversationID: String,
        content: String
    ) -> AsyncThrowingStream<PersistentAssistantStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let path = "v1/ai/assistant/conversations/\(conversationID)/stream"
                    var request = URLRequest(url: baseURL.appendingPathComponent(path))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    if let token = await authTokenProvider() {
                        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }
                    request.httpBody = try JSONEncoder().encode(PersistentAssistantTurnRequestDTO(content: content))

                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw Failure.invalidResponse
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
                        switch event {
                        case "started":
                            continuation.yield(.started)
                        case "turn":
                            guard let data = json.data(using: .utf8) else { throw Failure.invalidResponse }
                            continuation.yield(.turn(try JSONDecoder().decode(AIAssistantTurnResponse.self, from: data)))
                        case "error":
                            continuation.yield(.error(Self.field("message", in: json) ?? "The assistant could not complete this turn."))
                        case "done":
                            continuation.yield(.done)
                        default:
                            break
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
