import StockPlanShared
import SwiftUI

struct PersistentAssistantView: View {
    /// Prefills the composer without sending.
    ///
    /// Used by the per-screen summary sheets' "Continue in Q". Never
    /// auto-sent: the reader decides whether to ask, and a send would also
    /// write into the conversation a linked Telegram chat shares, growing that
    /// scrollback with a message nobody typed. The web app's `seed` query
    /// parameter behaves the same way.
    let seed: String?

    init(seed: String? = nil) {
        self.seed = seed
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = PersistentAssistantViewModel()
    @State private var showsConversations = false
    @State private var showsPreferences = false
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.activeConversation == nil {
                    ProgressView("Preparing your assistant…")
                } else {
                    conversationBody
                }
            }
            .vigilScreenBackground()
            // The Muse header pill names the agent; a second title would compete with it.
            .vigilNavigationTitle("")
            .vigilInlineNavigationBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink(value: SavedPositionMemosRoute()) { Image(systemName: "bookmark") }
                        .accessibilityLabel("Saved memos")
                    Button { showsPreferences = true } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("Assistant settings")
                }
            }
            .safeAreaInset(edge: .bottom) { composer }
            .navigationDestination(for: PositionMemoRoute.self) { route in
                PositionMemoReaderView(id: route.id, service: viewModel.memoService) { id, bookmarked in
                    viewModel.memoChanged(id: id, bookmarked: bookmarked)
                }
            }
            .navigationDestination(for: SavedPositionMemosRoute.self) { _ in
                SavedPositionMemosView(service: viewModel.memoService) { id, bookmarked in
                    viewModel.memoChanged(id: id, bookmarked: bookmarked)
                }
            }
            .task {
                await viewModel.load()
                // After `load`, which selects or creates the conversation and
                // would otherwise clear the field.
                if let seed, viewModel.draft.isEmpty {
                    viewModel.draft = seed
                }
            }
            .sheet(isPresented: $showsConversations) { conversationsSheet }
            .sheet(isPresented: $showsPreferences) { preferencesSheet }
            .alert("Q", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearMessage() } }
            )) { Button("OK", role: .cancel) { viewModel.clearMessage() } } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var conversationBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let usage = viewModel.usage { usageCaption(usage) }
                    if !viewModel.tips.isEmpty { tipsSection }
                    if viewModel.activeConversation?.messages.isEmpty ?? true,
                       viewModel.pendingActions.isEmpty,
                       !viewModel.isSending {
                        idleState
                    }
                    if let messages = viewModel.activeConversation?.messages {
                        ForEach(messages, id: \.id) { message in
                            VStack(spacing: 8) {
                                VStack(spacing: 4) {
                                    if let caption = MuseMessageCaption.text(for: message) {
                                        MuseProactiveCaption(text: caption)
                                    }
                                    MuseChatBubble(text: message.content, isUser: message.role == .user)
                                }
                                if let card = viewModel.memoCards[message.id] {
                                    PositionMemoCardView(
                                        card: card,
                                        isSaving: viewModel.memoBookmarkInFlight.contains(card.id)
                                    ) {
                                        Task { await viewModel.toggleBookmark(messageID: message.id) }
                                    }
                                }
                            }
                            .id(message.id)
                        }
                    }
                    ForEach(viewModel.pendingActions, id: \.id) { action in pendingActionCard(action).id(action.id) }
                    if viewModel.isSending {
                        MuseChatBubble(isUser: false) { ProgressView().controlSize(.small) }
                            .accessibilityLabel("Thinking")
                    }
                }
                .padding(.vertical, 16)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                MuseChatHeader(
                    status: viewModel.agentState.status,
                    phase: viewModel.agentState.phase,
                    onLeading: { showsConversations = true },
                    onNewChat: { Task { await viewModel.newConversation() } }
                )
            }
            .background(AppTheme.Colors.pageBackground(for: scheme))
            .vigilScreenBackground()
            .onChange(of: viewModel.activeConversation?.messages.count) {
                guard let id = viewModel.activeConversation?.messages.last?.id else { return }
                if reduceMotion {
                    proxy.scrollTo(id, anchor: .bottom)
                } else {
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
    }

    private var idleState: some View {
        VStack(spacing: 12) {
            Text("Ask Q. Nothing slips past.")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Add an expense, review your spending, or look up a stock.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            AssistantSuggestionChips { message in
                viewModel.draft = message
                Task { await viewModel.send() }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.horizontal, 24)
    }

    /// Remaining free requests, formerly in the status card. The Muse header's
    /// status line is reserved for the agent's state, so usage moves here.
    private func usageCaption(_ usage: AIAssistantUsageResponse) -> some View {
        Text(usage.isPro ? "Pro · unlimited" : "\(usage.remaining ?? 0) requests left this month")
            .font(.caption)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .contentTransition(.numericText())
            .frame(maxWidth: .infinity)
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NEEDS ATTENTION").font(.caption2.weight(.medium)).tracking(1.5).foregroundStyle(.secondary)
            ForEach(viewModel.tips, id: \.id) { tip in
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text(tip.title).font(.subheadline.weight(.semibold)); Spacer(); Button { Task { await viewModel.dismiss(tip) } } label: { Image(systemName: "xmark") }.buttonStyle(.plain).foregroundStyle(.secondary) }
                    Text(tip.body).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(16).background(AppTheme.Colors.cardBackground, in: .rect(cornerRadius: AppTheme.Radius.card))
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func pendingActionCard(_ action: AIPendingActionResponse) -> some View {
        let isBusy = viewModel.activeActionID == action.id
        if let task = viewModel.standingTask(for: action) {
            MuseStandingTaskCard(
                task: task,
                outcome: viewModel.standingTaskOutcomes[action.id],
                isBusy: isBusy,
                onConfirm: { Task { await viewModel.confirm(action) } },
                onNotNow: { Task { await viewModel.cancel(action) } }
            )
        } else {
            AssistantPendingActionCard(
                action: action,
                isBusy: isBusy,
                onConfirm: { Task { await viewModel.confirm(action) } },
                onCancel: { Task { await viewModel.cancel(action) } }
            )
        }
    }

    private var composer: some View {
        @Bindable var viewModel = viewModel
        return VStack(spacing: 0) {
            AssistantCommandSuggestionList(draft: viewModel.draft) { command in
                viewModel.draft = command.argumentHint == nil ? command.trigger : command.trigger + " "
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask about your finances", text: $viewModel.draft, axis: .vertical)
                    .focused($isComposerFocused)
                    .onChange(of: isComposerFocused) { _, focused in viewModel.composerFocusChanged(focused) }
                    .lineLimit(1...5).textFieldStyle(.plain)
                    .foregroundStyle(AppTheme.Colors.foreground)
                    .submitLabel(.send).onSubmit { Task { await viewModel.send() } }
                    .padding(.vertical, 8)
                Button { Task { await viewModel.send() } } label: { Image(systemName: "arrow.up.circle.fill").font(.title) }
                    .foregroundStyle(AppTheme.Colors.tint)
                    .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
                    .accessibilityLabel("Send")
            }
            .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 4)
            .background(AppTheme.Colors.tintSoft, in: .rect(cornerRadius: 24))
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(AppTheme.Colors.pageBackground)
        }
    }

    private var conversationsSheet: some View {
        NavigationStack {
            List {
                ForEach(viewModel.conversations, id: \.id) { conversation in
                    Button { Task { await viewModel.select(id: conversation.id); showsConversations = false } } label: {
                        VStack(alignment: .leading, spacing: 4) { Text(conversation.title); Text(conversation.updatedAt).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            .navigationTitle("Conversations")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { Task { await viewModel.newConversation(); showsConversations = false } } label: { Label("New", systemImage: "square.and.pencil") } } }
        }
        .presentationDetents([.medium, .large])
    }

    private var preferencesSheet: some View {
        NavigationStack {
            Form {
                Section("Proactive guidance") {
                    Toggle("Daily meaningful tips", isOn: Binding(
                        get: { viewModel.preferences?.proactiveTipsEnabled ?? false },
                        set: { value in Task { await viewModel.updatePreferences(proactiveTipsEnabled: value) } }
                    ))
                    Toggle("Push notifications", isOn: Binding(
                        get: { viewModel.preferences?.pushEnabled ?? false },
                        set: { value in Task { await viewModel.updatePreferences(pushEnabled: value) } }
                    ))
                }
                Section { Text("Conversations are encrypted and retained for 30 days. Financial changes always require confirmation.").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("Assistant settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showsPreferences = false } } }
        }
        .presentationDetents([.medium])
    }
}
