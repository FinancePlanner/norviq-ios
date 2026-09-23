import Foundation

/// What the Muse header avatar is doing (`_reviews/muse-chat-contract.md`,
/// "Avatar states + status copy"). No working mascot art exists, so `working`
/// is drawn as a ring around the idle art.
nonisolated enum MuseAgentPhase: Equatable, Sendable {
    case idle
    case listening
    case working
    case celebrating
}

/// Something that moves the header between states. Stream frames map one to
/// one; the rest come from the composer and the celebration timer.
nonisolated enum MuseAgentEvent: Equatable, Sendable {
    /// The user sent a message, or the stream reported `started`.
    case started
    /// A tool is running. `label` is the server's activity line, e.g. "Adding expense…".
    case tool(String)
    /// The final turn arrived.
    case turn
    /// The turn failed.
    case failed
    /// The 1.2s celebration is over.
    case celebrationEnded
    /// The composer gained or lost focus.
    case composerFocus(Bool)
}

/// The header's state and status line. `reduce` is pure so the whole mapping
/// is unit-testable without a view model or a stream.
nonisolated struct MuseAgentState: Equatable, Sendable {
    static let celebrationDuration: Duration = .milliseconds(1200)
    static let maxToolLabelLength = 32

    static let readyStatus = "Ready"
    static let listeningStatus = "is listening"
    static let thinkingStatus = "is thinking"
    static let failedStatus = "hit a snag"

    private(set) var phase: MuseAgentPhase = .idle
    private(set) var status: String = Self.readyStatus
    /// Remembered so the end of a turn can fall back to `listening` when the
    /// user is still in the composer.
    private(set) var isComposerFocused = false

    static let idle = MuseAgentState()

    func reduce(_ event: MuseAgentEvent) -> MuseAgentState {
        var next = self
        switch event {
        case .started:
            next.phase = .working
            next.status = Self.thinkingStatus
        case let .tool(label):
            // A late tool frame after the turn must not re-open the ring.
            guard phase == .working else { return self }
            next.status = Self.toolStatus(for: label)
        case .turn:
            next.phase = .celebrating
            next.status = Self.readyStatus
        case .failed:
            next.phase = .idle
            next.status = Self.failedStatus
        case .celebrationEnded:
            guard phase == .celebrating else { return self }
            next.settle()
        case let .composerFocus(focused):
            next.isComposerFocused = focused
            // Focus never interrupts a turn or its celebration.
            guard phase == .idle || phase == .listening else { return next }
            next.settle()
        }
        return next
    }

    private mutating func settle() {
        if isComposerFocused {
            phase = .listening
            status = Self.listeningStatus
        } else {
            phase = .idle
            status = Self.readyStatus
        }
    }

    /// "Adding expense…" → "is adding expense". Falls back to "is thinking"
    /// when the label is empty, and caps the label at 32 characters on a word
    /// boundary so the pill never wraps.
    static func toolStatus(for label: String) -> String {
        var text = label.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = text.last, last == "…" || last == "." {
            text.removeLast()
        }
        text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return thinkingStatus }

        // Lowercase the leading verb, but leave acronyms ("ETF", "AI") alone.
        let firstWord = text.prefix { !$0.isWhitespace }
        let isAcronym = firstWord.count > 1 && firstWord.allSatisfy { $0.isUppercase || $0.isNumber }
        if !isAcronym, let first = text.first {
            text = first.lowercased() + text.dropFirst()
        }

        if text.count > maxToolLabelLength {
            let limit = maxToolLabelLength - 1
            var cut = String(text.prefix(limit))
            if let space = cut.lastIndex(of: " "), cut.distance(from: cut.startIndex, to: space) > limit / 2 {
                cut = String(cut[..<space])
            }
            text = cut.trimmingCharacters(in: .whitespaces) + "…"
        }
        return "is \(text)"
    }
}
