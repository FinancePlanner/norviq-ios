@preconcurrency import AVFoundation
import UIKit

/// Reads an answer aloud after a spoken question.
///
/// Uses the ambient audio category, so the silent switch mutes it: a muted phone
/// must not read someone's finances out loud.
@MainActor
final class VoiceReplySpeaker: NSObject {
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ markdown: String, language: AppLanguage = .stored) {
        stop()
        // VoiceOver already announces the answer, and two voices can't be followed.
        guard !UIAccessibility.isVoiceOverRunning,
              let voice = AVSpeechSynthesisVoice(language: language.speechIdentifier)
        else { return }
        let text = Self.spokenText(from: markdown)
        guard !text.isEmpty else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient)
            try session.setActive(true)
        } catch {
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        synthesizer.speak(utterance)
    }

    func stop() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func releaseAudioSession() {
        guard !synthesizer.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// One sentence per Markdown line, with the markers gone, so nothing like
    /// "asterisk asterisk" gets read out.
    nonisolated static func spokenText(from markdown: String) -> String {
        markdown
            .split(whereSeparator: \.isNewline)
            .compactMap(spokenLine)
            .joined(separator: " ")
    }

    private nonisolated static func spokenLine(_ raw: Substring) -> String? {
        var line = raw.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty, line.wholeMatch(of: /[\s:|-]*-[\s:|-]*/) == nil else { return nil }
        line = line
            .replacing(/^#{1,6}\s+/, with: "")
            .replacing(/^[-*+]\s+/, with: "")
            .replacing(/^\d+[.)]\s+/, with: "")
            .replacing(/^>\s*/, with: "")
        if line.contains("|") {
            line = line
                .split(separator: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        }
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let parsed = try? AttributedString(markdown: line, options: options) {
            line = String(parsed.characters)
        }
        guard let last = line.last else { return nil }
        return ".!?…".contains(last) ? line : line + "."
    }
}

extension VoiceReplySpeaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.releaseAudioSession() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.releaseAudioSession() }
    }
}
