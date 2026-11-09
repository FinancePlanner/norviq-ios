import PhotosUI
import StockPlanShared
import SwiftUI

/// The floating card: the latest question and answer above a composer.
struct QuickAssistantCard: View {
    @Bindable var viewModel: QuickAssistantViewModel
    let onSend: () -> Void
    let onClose: () -> Void
    let onOpenInQ: (String) -> Void
    /// Nil hides the mic: this language has no on-device speech recognition.
    let voice: VoiceInputController?
    let onMic: () -> Void
    /// Any touch on the card stops a reply being read aloud.
    let onTouch: () -> Void

    @State private var exchangeHeight: CGFloat = 0

    private var isListening: Bool { voice?.isListening == true }

    private var notice: LocalizedStringKey? {
        switch voice?.failure {
        case .permissionDenied: "Allow the microphone and speech recognition in Settings, or type your question."
        case .notHeard: "Couldn't hear that. Try again or type your question."
        case nil: nil
        }
    }

    private var canSend: Bool {
        guard !viewModel.isThinking, viewModel.preparingAttachmentCount == 0 else { return false }
        return !viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.attachments.isEmpty
    }

    private var canAttach: Bool { viewModel.imagesEnabled || viewModel.documentsEnabled }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            exchange
            if let notice {
                Text(notice)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            attachmentStrip
            composer
        }
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
        .simultaneousGesture(TapGesture().onEnded(onTouch))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
    }

    private var header: some View {
        HStack {
            Label("Ask Q", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.foreground)
            Spacer()
            if let conversationID = viewModel.conversationID, viewModel.phase == .answered {
                Button("Open in Q") { onOpenInQ(conversationID) }
                    .font(.subheadline)
                    .tint(AppTheme.Colors.tint)
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(.rect)
            }
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .accessibilityLabel("Close Q")
        }
    }

    /// Long answers scroll inside the card, short ones keep it small. A maximum
    /// rather than a fixed height, so the keyboard can squeeze it on small phones.
    @ViewBuilder private var exchange: some View {
        if viewModel.question != nil || viewModel.phase != .idle {
            ScrollView {
                exchangeContent
                    .onGeometryChange(for: CGFloat.self, of: \.size.height) { exchangeHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .frame(maxHeight: min(exchangeHeight, 320))
        }
    }

    private var exchangeContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let question = viewModel.question {
                Text(verbatim: question)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            switch viewModel.phase {
            case let .thinking(activity):
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    if let activity {
                        Text(verbatim: activity)
                    } else {
                        Text("Thinking…")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
            case let .failed(message):
                Text(verbatim: message)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            case .idle, .answered:
                EmptyView()
            }
            // A turn that proposes a change only says what the card below shows.
            if let answer = viewModel.answer, viewModel.pendingAction == nil {
                Text(Self.rendered(answer))
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.foreground)
                    .textSelection(.enabled)
            }
            if let action = viewModel.pendingAction {
                AssistantPendingActionCard(
                    action: action,
                    isBusy: viewModel.isActing,
                    onConfirm: { Task { await viewModel.confirmPendingAction() } },
                    onCancel: { Task { await viewModel.cancelPendingAction() } }
                )
                .padding(.horizontal, -16)
            }
            if let error = viewModel.actionError {
                Text(verbatim: error)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One line high: chips scroll sideways inside the strip.
    private var attachmentStrip: some View {
        AssistantAttachmentStrip(
            attachments: viewModel.attachments,
            preparingCount: viewModel.preparingAttachmentCount,
            notice: viewModel.attachmentNotice,
            framed: false,
            onRemove: { viewModel.removeAttachment(id: $0) }
        )
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if canAttach {
                AssistantAttachMenu(
                    imagesEnabled: viewModel.imagesEnabled,
                    documentsEnabled: viewModel.documentsEnabled,
                    room: viewModel.attachmentRoom,
                    isDisabled: viewModel.isThinking || isListening,
                    onPhotos: { items in
                        Task {
                            await viewModel.addAttachments(items.map { item in { try? await item.loadTransferable(type: Data.self) } })
                        }
                    },
                    onCamera: { data in Task { await viewModel.addAttachments([{ data }]) } },
                    onFiles: { urls in Task { await viewModel.addFiles(urls) } }
                )
                .padding(.bottom, 2)
            }
            TextField(
                isListening ? "Listening…" : "Ask about your finances",
                text: $viewModel.draft,
                axis: .vertical
            )
                .disabled(isListening)
                .accessibilityIdentifier("quickAssistant.composer")
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.Colors.foreground)
                .padding(.vertical, 8)
            trailingButton
                .padding(.bottom, 4)
        }
        .padding(.leading, canAttach ? 6 : 16)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(AppTheme.Colors.tintSoft, in: .rect(cornerRadius: 20))
    }

    /// The mic while there is nothing to send, as in Messages, so a typed draft
    /// can't be overwritten by listening.
    @ViewBuilder private var trailingButton: some View {
        if isListening {
            Button(action: onMic) {
                Image(systemName: "stop.circle.fill").font(.title2)
            }
            .foregroundStyle(AppTheme.Colors.tint)
            .accessibilityLabel("Stop listening")
        } else if voice != nil, viewModel.draft.isEmpty, !viewModel.isThinking {
            // With a file pending, the mic sits beside Send: speak a question
            // about it, or send the file alone.
            HStack(spacing: 4) {
                Button(action: onMic) {
                    Image(systemName: "mic.circle.fill").font(.title2)
                }
                .foregroundStyle(AppTheme.Colors.tint)
                .accessibilityLabel("Ask by voice")
                if !viewModel.attachments.isEmpty { sendButton }
            }
        } else {
            sendButton
        }
    }

    private var sendButton: some View {
        Button(action: onSend) {
            Image(systemName: "arrow.up.circle.fill").font(.title2)
        }
        .foregroundStyle(AppTheme.Colors.tint)
        .opacity(canSend ? 1 : 0.4)
        .disabled(!canSend)
        .accessibilityLabel("Send")
    }

    private static func rendered(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}
