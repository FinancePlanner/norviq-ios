//
//  EarningsAudioPlayer.swift
//  financeplan
//
//  Speaks an earnings-call transcript aloud with on-device text-to-speech.
//  Supports background playback and lock-screen now-playing controls — this is
//  the app's persistent-audio feature that justifies the `audio` UIBackgroundMode.
//

import AVFoundation
import Foundation
import MediaPlayer
import Observation
import OSLog

@Observable
final class EarningsAudioPlayer: NSObject {
    enum Playback: Equatable {
        case idle
        case playing(String)
        case paused(String)
    }

    private(set) var playback: Playback = .idle

    private let synthesizer = AVSpeechSynthesizer()
    private var nowPlayingTitle = ""
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
        category: "EarningsAudioPlayer"
    )

    override init() {
        super.init()
        synthesizer.delegate = self
        configureRemoteCommands()
    }

    // MARK: - Query

    func isPlaying(_ transcript: EarningsTranscript) -> Bool {
        playback == .playing(transcript.id)
    }

    func isActive(_ transcript: EarningsTranscript) -> Bool {
        switch playback {
        case .playing(let id), .paused(let id): return id == transcript.id
        case .idle: return false
        }
    }

    // MARK: - Control

    /// Play / pause toggle for the given transcript. Starting a different
    /// transcript stops the current one first.
    func toggle(_ transcript: EarningsTranscript) {
        switch playback {
        case .playing(let id) where id == transcript.id: pause()
        case .paused(let id) where id == transcript.id: resume()
        default: start(transcript)
        }
    }

    func start(_ transcript: EarningsTranscript) {
        stop()

        let text = transcript.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        activateSession()
        nowPlayingTitle = title(for: transcript)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        synthesizer.speak(utterance)

        playback = .playing(transcript.id)
        updateNowPlaying(isPlaying: true)
    }

    func pause() {
        guard case .playing(let id) = playback else { return }
        synthesizer.pauseSpeaking(at: .word)
        playback = .paused(id)
        updateNowPlaying(isPlaying: false)
    }

    func resume() {
        guard case .paused(let id) = playback else { return }
        synthesizer.continueSpeaking()
        playback = .playing(id)
        updateNowPlaying(isPlaying: true)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        teardown()
    }

    // MARK: - Private

    private func teardown() {
        playback = .idle
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            logger.error("Audio session activation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func title(for transcript: EarningsTranscript) -> String {
        let quarter = transcript.quarter > 0 ? "Q\(transcript.quarter) " : ""
        let year = transcript.year > 0 ? "\(transcript.year) " : ""
        return "\(transcript.symbol) \(quarter)\(year)Earnings Call"
    }

    private func updateNowPlaying(isPlaying: Bool) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle] = nowPlayingTitle
        info[MPMediaItemPropertyArtist] = "Norviq · Earnings Transcript"
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.resume()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.pause()
            return .success
        }
        center.stopCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.stop()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            switch self.playback {
            case .playing: self.pause()
            case .paused: self.resume()
            case .idle: break
            }
            return .success
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension EarningsAudioPlayer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in self.teardown() }
    }
}
