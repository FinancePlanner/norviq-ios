@preconcurrency import AVFoundation
import Observation
@preconcurrency import Speech

nonisolated extension AppLanguage {
    /// The recognizer and the synthesizer both need a language and a region.
    var speechIdentifier: String {
        switch self {
        case .english: "en-US"
        case .portuguesePortugal: "pt-PT"
        }
    }
}

/// Turns one spoken question into text, on the device only. Audio never leaves
/// the phone: a language without on-device recognition has no mic button at all.
///
/// The audio tap and the speech callbacks run off the main actor. They are
/// created in `nonisolated` functions and marked `@Sendable`, because a closure
/// that inherits this type's isolation crashes when the system calls it.
@Observable @MainActor
final class VoiceInputController {
    enum Failure: Equatable {
        case permissionDenied
        case notHeard
    }

    private static let silenceAfterSpeech = Duration.seconds(1.8)
    private static let silenceBeforeSpeech = Duration.seconds(8)
    private static let longestQuestion = Duration.seconds(60)

    private(set) var isListening = false
    private(set) var failure: Failure?

    @ObservationIgnored private var attempt = 0
    @ObservationIgnored private var transcript = ""
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var silenceTimer: Task<Void, Never>?
    @ObservationIgnored private var lengthTimer: Task<Void, Never>?
    @ObservationIgnored private var onPartial: ((String) -> Void)?
    @ObservationIgnored private var onFinish: ((String) -> Void)?

    static func isSupported(language: AppLanguage = .stored) -> Bool {
        recognizer(for: language)?.supportsOnDeviceRecognition == true
    }

    /// Listens until silence, `finish()` or the length cap, then hands over the text.
    func start(
        language: AppLanguage = .stored,
        onPartial: @escaping (String) -> Void,
        onFinish: @escaping (String) -> Void
    ) async {
        cancel()
        let current = attempt
        let isAllowed = await Self.requestPermissions()
        // Closed, or sent to the background, while the permission prompt was up.
        guard current == attempt else { return }
        guard isAllowed else {
            failure = .permissionDenied
            return
        }
        self.onPartial = onPartial
        self.onFinish = onFinish
        do {
            try begin(language: language, attempt: current)
        } catch {
            stopAudio()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            failure = .notHeard
        }
    }

    /// Ends the question early and hands over what was heard.
    func finish() {
        guard isListening else { return }
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let onFinish = onFinish
        cancel()
        if text.isEmpty {
            failure = .notHeard
        } else {
            onFinish?(text)
        }
    }

    /// Stops listening and drops what was heard, and any failure notice.
    func cancel() {
        attempt += 1
        failure = nil
        stopAudio()
    }

    private func begin(language: AppLanguage, attempt current: Int) throws {
        guard let recognizer = Self.recognizer(for: language),
              recognizer.supportsOnDeviceRecognition,
              recognizer.isAvailable
        else {
            throw Failure.notHeard
        }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true

        let engine = AVAudioEngine()
        try Self.installTap(on: engine, sendingTo: request)
        self.engine = engine
        self.request = request
        engine.prepare()
        try engine.start()

        transcript = ""
        isListening = true
        task = Self.startRecognition(with: recognizer, request: request, owner: self, attempt: current)
        restartSilenceTimer(after: Self.silenceBeforeSpeech)
        lengthTimer = Task { [weak self] in
            try? await Task.sleep(for: Self.longestQuestion)
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    private func handleRecognition(text: String?, isFinal: Bool, didFail: Bool, attempt current: Int) {
        guard current == attempt, isListening else { return }
        if let text, text != transcript {
            transcript = text
            onPartial?(text)
            restartSilenceTimer(after: Self.silenceAfterSpeech)
        }
        if isFinal || didFail { finish() }
    }

    private func restartSilenceTimer(after delay: Duration) {
        silenceTimer?.cancel()
        silenceTimer = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    private func stopAudio() {
        silenceTimer?.cancel()
        lengthTimer?.cancel()
        silenceTimer = nil
        lengthTimer = nil
        onPartial = nil
        onFinish = nil
        transcript = ""
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        if let engine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            self.engine = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        isListening = false
    }

    private static func recognizer(for language: AppLanguage) -> SFSpeechRecognizer? {
        SFSpeechRecognizer(locale: Locale(identifier: language.speechIdentifier))
    }

    private nonisolated static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status)
            }
        }
        guard speech == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    private nonisolated static func installTap(
        on engine: AVAudioEngine,
        sendingTo request: SFSpeechAudioBufferRecognitionRequest
    ) throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // Installing a tap with an empty format is an uncatchable crash.
        guard format.sampleRate > 0, format.channelCount > 0 else { throw Failure.notHeard }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable buffer, _ in
            request.append(buffer)
        }
    }

    private nonisolated static func startRecognition(
        with recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        owner: VoiceInputController,
        attempt: Int
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { @Sendable [weak owner] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let didFail = error != nil
            Task { @MainActor in
                owner?.handleRecognition(text: text, isFinal: isFinal, didFail: didFail, attempt: attempt)
            }
        }
    }
}

extension VoiceInputController.Failure: Error {}
