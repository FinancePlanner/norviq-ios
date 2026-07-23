import StockPlanShared
import SwiftUI

struct PersistentAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var viewModel = PersistentAssistantViewModel()
    @State private var showsConversations = false
    @State private var showsPreferences = false

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
            .navigationTitle("Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showsConversations = true } label: { Image(systemName: "clock.arrow.circlepath") }
                        .accessibilityLabel("Conversations")
                    Button { showsPreferences = true } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("Assistant settings")
                }
            }
            .safeAreaInset(edge: .bottom) { composer }
            .task { await viewModel.load() }
            .sheet(isPresented: $showsConversations) { conversationsSheet }
            .sheet(isPresented: $showsPreferences) { preferencesSheet }
            .alert("Assistant", isPresented: Binding(
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
                    statusHeader
                    if !viewModel.tips.isEmpty { tipsSection }
                    if viewModel.activeConversation?.messages.isEmpty ?? true,
                       viewModel.pendingActions.isEmpty,
                       !viewModel.isSending {
                        idleState
                    }
                    if let messages = viewModel.activeConversation?.messages {
                        ForEach(messages, id: \.id) { message in messageBubble(message).id(message.id) }
                    }
                    ForEach(viewModel.pendingActions, id: \.id) { action in pendingActionCard(action).id(action.id) }
                    if viewModel.isSending { HStack { ProgressView(); Text("Thinking…").foregroundStyle(.secondary); Spacer() }.padding(.horizontal, 16) }
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: viewModel.activeConversation?.messages.count) {
                if let id = viewModel.activeConversation?.messages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
            }
        }
    }

    private var idleState: some View {
        VStack(spacing: 12) {
            Image("CerberusHeadIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(AppTheme.Colors.tint(for: scheme))
                .shadow(color: AppTheme.Colors.tint(for: scheme).opacity(0.25), radius: 14, x: 0, y: 6)
                .accessibilityHidden(true)
            Text("Ask. The third head is listening.")
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
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }

    private var statusHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.activeConversation?.title ?? "New conversation").font(.headline)
                if let usage = viewModel.usage {
                    Text(usage.isPro ? "Pro · unlimited" : "\(usage.remaining ?? 0) requests left this month")
                        .font(.caption).foregroundStyle(.secondary).contentTransition(.numericText())
                }
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 10))
        .padding(.horizontal, 16)
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NEEDS ATTENTION").font(.caption2.weight(.medium)).tracking(1.5).foregroundStyle(.secondary)
            ForEach(viewModel.tips, id: \.id) { tip in
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text(tip.title).font(.subheadline.weight(.semibold)); Spacer(); Button { Task { await viewModel.dismiss(tip) } } label: { Image(systemName: "xmark") }.buttonStyle(.plain).foregroundStyle(.secondary) }
                    Text(tip.body).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(16).background(Color(.secondarySystemGroupedBackground)).clipShape(.rect(cornerRadius: 10))
            }
        }
        .padding(.horizontal, 16)
    }

    private func messageBubble(_ message: AIMessageResponse) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }
            Text(message.content)
                .font(.body)
                .foregroundStyle(message.role == .user ? Color.white : Color.primary)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(message.role == .user ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 10))
            if message.role != .user { Spacer(minLength: 48) }
        }
        .padding(.horizontal, 16)
    }

    private func pendingActionCard(_ action: AIPendingActionResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Confirmation required", systemImage: "checkmark.shield").font(.subheadline.weight(.semibold))
            Text(action.summary).font(.body)
            HStack(spacing: 8) {
                Button("Confirm") { Task { await viewModel.confirm(action) } }.buttonStyle(.borderedProminent)
                Button("Cancel", role: .cancel) { Task { await viewModel.cancel(action) } }.buttonStyle(.bordered)
                if viewModel.activeActionID == action.id { ProgressView().controlSize(.small) }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 10))
        .padding(.horizontal, 16)
    }

    private var composer: some View {
        @Bindable var viewModel = viewModel
        return VStack(spacing: 0) {
            AssistantCommandSuggestionList(draft: viewModel.draft) { command in
                viewModel.draft = command.argumentHint == nil ? command.trigger : command.trigger + " "
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask about your finances", text: $viewModel.draft, axis: .vertical)
                    .lineLimit(1...5).textFieldStyle(.roundedBorder)
                    .submitLabel(.send).onSubmit { Task { await viewModel.send() } }
                Button { Task { await viewModel.send() } } label: { Image(systemName: "arrow.up.circle.fill").font(.title) }
                    .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
                    .accessibilityLabel("Send")
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(.bar)
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
