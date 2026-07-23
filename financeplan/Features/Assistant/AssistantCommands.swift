//
//  AssistantCommands.swift
//  financeplan
//
//  Slash-command registry shared by both assistant surfaces. A leading
//  "/command" in the composer expands into a rich prompt before it reaches
//  the model; the raw command stays visible in the transcript.
//

import Foundation

nonisolated struct AssistantCommand: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let synopsis: String
    let argumentHint: String?

    var trigger: String { "/" + id }

    /// The prompt actually sent to the model for this command.
    func expandedPrompt(arguments: String) -> String {
        let args = arguments.trimmingCharacters(in: .whitespacesAndNewlines)
        switch id {
        case "expenses":
            let scope = args.isEmpty ? "recent" : args
            return "Summarize my \(scope) expenses using my real expense data: total spent, top categories, and anything unusual. Keep it concise."
        case "budget":
            let scope = args.isEmpty ? "" : " focusing on \(args)"
            return "Review my budgets\(scope): how much of each budget is used, where I am over or at risk, and one concrete adjustment to consider."
        case "stocks":
            if args.isEmpty {
                return "Review the stocks in my holdings and watchlist: today's notable movers and anything that needs my attention."
            }
            return "Give me a snapshot of \(args): current price, today's move, and any notable recent news or sentiment."
        case "portfolio":
            let scope = args.isEmpty ? "" : " focusing on \(args)"
            return "Summarize my portfolio\(scope): total value, today's change, allocation breakdown, and best and worst performers."
        default:
            return args.isEmpty ? trigger : "\(trigger) \(args)"
        }
    }
}

nonisolated enum AssistantCommandRegistry {
    static let all: [AssistantCommand] = [
        AssistantCommand(
            id: "expenses",
            title: "Expenses",
            synopsis: "Summarize recent spending",
            argumentHint: "this month"
        ),
        AssistantCommand(
            id: "budget",
            title: "Budget",
            synopsis: "Check budget usage and risks",
            argumentHint: nil
        ),
        AssistantCommand(
            id: "stocks",
            title: "Stocks",
            synopsis: "Snapshot of a ticker or your watchlist",
            argumentHint: "AAPL"
        ),
        AssistantCommand(
            id: "portfolio",
            title: "Portfolio",
            synopsis: "Value, allocation, and performers",
            argumentHint: nil
        ),
    ]

    static func command(named name: String) -> AssistantCommand? {
        all.first { $0.id == name.lowercased() }
    }

    /// Commands matching a draft like "/", "/ex" — used for the composer
    /// autocomplete. Empty once the draft stops looking like a command prefix.
    static func suggestions(for draft: String) -> [AssistantCommand] {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("/"), !trimmed.contains(" "), !trimmed.contains("\n") else { return [] }
        let prefix = String(trimmed.dropFirst()).lowercased()
        guard all.first(where: { $0.id == prefix }) == nil else { return [] }
        return prefix.isEmpty ? all : all.filter { $0.id.hasPrefix(prefix) }
    }

    static var helpText: String {
        let lines = all.map { command in
            let hint = command.argumentHint.map { " [\($0)]" } ?? ""
            return "\(command.trigger)\(hint) — \(command.synopsis)"
        }
        return (["Here's what I can do with a quick command:"] + lines)
            .joined(separator: "\n")
    }
}

nonisolated enum AssistantCommandResolution: Equatable {
    /// Regular free-text message; send as-is.
    case plain(String)
    /// Known command; send `expandedPrompt` to the model, show the raw text.
    case command(AssistantCommand, expandedPrompt: String)
    /// Answer locally without a network round-trip (/help, unknown commands).
    case local(reply: String)
}

nonisolated enum AssistantCommandParser {
    static func resolve(_ text: String) -> AssistantCommandResolution {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return .plain(trimmed) }

        let body = trimmed.dropFirst()
        let parts = body.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let name = parts.first.map(String.init)?.lowercased() ?? ""
        let arguments = parts.count > 1 ? String(parts[1]) : ""

        if name.isEmpty || name == "help" {
            return .local(reply: AssistantCommandRegistry.helpText)
        }
        guard let command = AssistantCommandRegistry.command(named: name) else {
            return .local(reply: "I don't know /\(name).\n\n\(AssistantCommandRegistry.helpText)")
        }
        return .command(command, expandedPrompt: command.expandedPrompt(arguments: arguments))
    }
}

/// First-run suggestion chips shared by both assistant empty states.
nonisolated enum AssistantSuggestions {
    struct Chip: Identifiable, Equatable {
        let id: String
        let label: String
        let message: String
    }

    static let all: [Chip] = [
        Chip(id: "expenses", label: "/expenses this month", message: "/expenses this month"),
        Chip(id: "portfolio", label: "/portfolio summary", message: "/portfolio"),
        Chip(id: "budget", label: "/budget check", message: "/budget"),
        Chip(id: "inflation", label: "US inflation now", message: "How is US inflation trending right now, and what does it mean for my spending?"),
    ]
}
