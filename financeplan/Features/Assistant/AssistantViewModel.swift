//
//  AssistantViewModel.swift
//  financeplan
//

import Factory
import Foundation
import Observation

/// A single message in the assistant conversation.
struct AssistantMessage: Identifiable, Equatable {
    enum Role: Equatable { case user, assistant }
    let id = UUID()
    let role: Role
    var text: String
}

@MainActor
@Observable
final class AssistantViewModel {
    private(set) var messages: [AssistantMessage] = []
    private(set) var isStreaming = false
    private(set) var toolActivity: String?
    var errorMessage: String?
    var draft: String = ""

    private let client: AssistantStreamClient

    init(client: AssistantStreamClient = Container.shared.assistantStreamClient()) {
        self.client = client
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        draft = ""
        errorMessage = nil
        messages.append(AssistantMessage(role: .user, text: text))

        let outgoingContent: String
        switch AssistantCommandParser.resolve(text) {
        case let .local(reply):
            messages.append(AssistantMessage(role: .assistant, text: reply))
            return
        case let .command(_, expandedPrompt):
            outgoingContent = expandedPrompt
        case let .plain(content):
            outgoingContent = content
        }

        var history = messages.map {
            AssistantChatMessageDTO(role: $0.role == .user ? "user" : "assistant", content: $0.text)
        }
        history[history.count - 1] = AssistantChatMessageDTO(role: "user", content: outgoingContent)

        isStreaming = true
        toolActivity = nil
        Task { await consume(history: history) }
    }

    /// Sends a suggestion chip or autocompleted command as if typed.
    func send(message: String) {
        guard !isStreaming else { return }
        draft = message
        send()
    }

    private func consume(history: [AssistantChatMessageDTO]) async {
        defer { isStreaming = false; toolActivity = nil }
        do {
            for try await event in client.stream(messages: history) {
                switch event {
                case let .tool(label):
                    toolActivity = label
                case let .message(content):
                    toolActivity = nil
                    messages.append(AssistantMessage(role: .assistant, text: content))
                case .done:
                    return
                }
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Please try again."
        }
    }
}
