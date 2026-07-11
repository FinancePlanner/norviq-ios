//
//  AssistantView.swift
//  financeplan
//
//  The in-app conversational assistant. Talks to POST /v1/ai/chat over SSE and
//  renders the streamed tool-activity + assistant messages.
//

import SwiftUI

struct AssistantView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AssistantViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messagesList
                inputBar
            }
            .background(AppTheme.Colors.pageBackground(for: scheme))
            .navigationTitle("Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if viewModel.messages.isEmpty {
                        emptyState
                    }
                    ForEach(viewModel.messages) { message in
                        AssistantBubble(message: message)
                            .id(message.id)
                    }
                    if let activity = viewModel.toolActivity {
                        toolActivityRow(activity)
                    }
                    if let error = viewModel.errorMessage {
                        FormErrorBanner(message: error)
                    }
                }
                .padding(16)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ask me anything about your money", systemImage: "sparkles")
                .typography(.headline, weight: .semibold)
            Text("Add an expense, review your spending, or look up a stock — just ask.")
                .typography(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 40)
    }

    private func toolActivityRow(_ label: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(label)
                .typography(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message", text: $viewModel.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.Colors.elevatedCardBackground(for: scheme), in: .capsule)
                .lineLimit(1 ... 5)
                .disabled(viewModel.isStreaming)

            Button {
                viewModel.send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(viewModel.canSend ? AppTheme.Colors.tint(for: scheme) : .secondary)
            }
            .disabled(!viewModel.canSend)
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }
}

private struct AssistantBubble: View {
    @Environment(\.colorScheme) private var scheme
    let message: AssistantMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .typography(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleBackground, in: .rect(cornerRadius: 18))
                .foregroundStyle(message.role == .user ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var bubbleBackground: Color {
        message.role == .user
            ? AppTheme.Colors.tint(for: scheme)
            : AppTheme.Colors.elevatedCardBackground(for: scheme)
    }
}
