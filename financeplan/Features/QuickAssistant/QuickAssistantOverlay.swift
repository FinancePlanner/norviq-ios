import Combine
import Factory
import SwiftUI

/// Hosts the Quick Q card and its floating button over the current screen.
///
/// An overlay rather than a sheet: it sits over the tab bar and under
/// `AppLockOverlay`, and it never hits the "second sheet is ignored" trap when
/// a screen's own sheets are in play.
struct QuickAssistantOverlay: View {
    let onOpenInQ: (String) -> Void
    let onPaywall: () -> Void
    /// A hint for the floating button's questions. Nil on tabs with no matching scope.
    let currentScope: AIViewScope?
    /// False during the guided start, whose scrim must stay on top of everything.
    let allowsFloatingButton: Bool

    @InjectedObservable(\.quickAssistantCoordinator) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = QuickAssistantViewModel()
    @State private var sendTask: Task<Void, Never>?
    @State private var voice = VoiceInputController()
    @State private var speaker = VoiceReplySpeaker()
    @State private var isVoiceSupported = false

    /// A push tap is going to change what is on screen, so the card gets out of
    /// its way.
    private static let closingEvents = Publishers.MergeMany(
        [
            Notification.Name.openAssistantFromPushNotification,
            .openBoardPostFromPushNotification,
            .openBudgetFromPushNotification,
            .openGroupsFromPushNotification,
            .openMarketBriefFromPushNotification,
            .openPortfolioFromPushNotification,
            .openSocialFromPushNotification,
            .openStockFromPushNotification,
            .openTaxFromPushNotification,
            .openThesisWatchFromPushNotification,
        ].map { NotificationCenter.default.publisher(for: $0) }
    )

    var body: some View {
        ZStack(alignment: .bottom) {
            if allowsFloatingButton, coordinator.showsFloatingButton {
                QuickAssistantFloatingButton { coordinator.present(scope: currentScope) }
                    .transition(.opacity)
            }
            if coordinator.isPresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { coordinator.dismiss() }
                    .accessibilityHidden(true)
                    .transition(.opacity)
                QuickAssistantCard(
                    viewModel: viewModel,
                    onSend: send,
                    onClose: { coordinator.dismiss() },
                    onOpenInQ: { conversationID in
                        coordinator.dismiss()
                        onOpenInQ(conversationID)
                    },
                    voice: isVoiceSupported ? voice : nil,
                    onMic: toggleListening,
                    onTouch: { speaker.stop() }
                )
                .transition(AppTransition.move(edge: .bottom, reduceMotion: reduceMotion))
            }
        }
        .appAnimation(AppMotion.structural, value: coordinator.isPresented)
        .onChange(of: coordinator.isPresented) { _, presented in
            guard !presented else {
                isVoiceSupported = VoiceInputController.isSupported()
                Task { await viewModel.loadAttachmentFlags() }
                return
            }
            stopVoice()
            sendTask?.cancel()
            sendTask = nil
            viewModel.reset()
        }
        .onChange(of: viewModel.isPaywallRequested) { _, requested in
            guard requested else { return }
            viewModel.isPaywallRequested = false
            onPaywall()
        }
        .onChange(of: viewModel.answer) { _, answer in
            guard let answer else { return }
            AccessibilityNotification.Announcement(answer).post()
        }
        .onChange(of: scenePhase) { _, phase in
            // Not `.inactive`: the permission prompts cause that.
            if phase == .background { stopVoice() }
        }
        .onReceive(Self.closingEvents) { _ in coordinator.dismiss() }
    }

    private func send() {
        stopVoice()
        let scope = coordinator.scope
        sendTask = Task { await viewModel.send(scope: scope) }
    }

    /// Opening the card never starts the mic. Only this tap does.
    private func toggleListening() {
        if voice.isListening {
            voice.finish()
            return
        }
        speaker.stop()
        Task {
            await voice.start(
                onPartial: { viewModel.draft = $0 },
                onFinish: sendSpokenQuestion
            )
        }
    }

    private func sendSpokenQuestion(_ text: String) {
        viewModel.draft = text
        let scope = coordinator.scope
        sendTask = Task {
            await viewModel.send(scope: scope, inputMode: .voice)
            guard !Task.isCancelled, viewModel.phase == .answered, let answer = viewModel.answer else { return }
            speaker.speak(answer)
        }
    }

    private func stopVoice() {
        voice.cancel()
        speaker.stop()
    }
}
