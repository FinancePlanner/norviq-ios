//
//  AssistantCommandViews.swift
//  financeplan
//
//  Shared UI for slash commands: first-run suggestion chips and the composer
//  autocomplete list. Used by both assistant surfaces. Also the cards that
//  ask the user to confirm an action the assistant proposed.
//

import StockPlanShared
import SwiftUI

/// Tappable starter chips for the assistant empty states.
struct AssistantSuggestionChips: View {
    @Environment(\.colorScheme) private var scheme
    let onSelect: (String) -> Void

    var body: some View {
        FlowChips(chips: AssistantSuggestions.all, onSelect: onSelect)
    }

    private struct FlowChips: View {
        @Environment(\.colorScheme) private var scheme
        let chips: [AssistantSuggestions.Chip]
        let onSelect: (String) -> Void

        var body: some View {
            VStack(spacing: 8) {
                ForEach(chips) { chip in
                    Button {
                        onSelect(chip.message)
                    } label: {
                        Text(chip.label)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                AppTheme.Colors.elevatedCardBackground(for: scheme),
                                in: .capsule
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    AppTheme.Colors.tint(for: scheme).opacity(0.25),
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Autocomplete list shown above the composer while the draft looks like a
/// slash-command prefix ("/", "/ex", …).
struct AssistantCommandSuggestionList: View {
    @Environment(\.colorScheme) private var scheme
    let draft: String
    let onSelect: (AssistantCommand) -> Void

    private var suggestions: [AssistantCommand] {
        AssistantCommandRegistry.suggestions(for: draft)
    }

    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(suggestions) { command in
                    Button {
                        onSelect(command)
                    } label: {
                        HStack(spacing: 10) {
                            Text(command.trigger)
                                .font(.subheadline.weight(.semibold))
                                .monospaced()
                                .foregroundStyle(AppTheme.Colors.tint(for: scheme))
                            Text(command.synopsis)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if let hint = command.argumentHint {
                                Text(hint)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    if command.id != suggestions.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(.thinMaterial)
            .clipShape(.rect(cornerRadius: 12))
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeOut(duration: 0.15), value: suggestions)
        }
    }
}

/// Asks the user to confirm a write the assistant proposed.
struct AssistantPendingActionCard: View {
    let action: AIPendingActionResponse
    let isBusy: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Confirmation required", systemImage: "checkmark.shield").font(.subheadline.weight(.semibold))
            Text(action.summary).font(.body)
            HStack(spacing: 8) {
                Button("Confirm", action: onConfirm).buttonStyle(.borderedProminent)
                Button("Cancel", role: .cancel, action: onCancel).buttonStyle(.bordered)
                if isBusy { ProgressView().controlSize(.small) }
            }
            .disabled(isBusy)
        }
        .padding(16)
        .background(AppTheme.Colors.cardBackground, in: .rect(cornerRadius: AppTheme.Radius.card))
        .padding(.horizontal, 16)
    }
}

/// Muse standing-task card (`_reviews/muse-chat-contract.md`): agent-bubble
/// styled, with the task's title, human schedule and spec, and Confirm /
/// Not now. Confirming makes the agent post a "Standing task" message, which
/// the transcript shows in place of this card.
struct MuseStandingTaskCard: View {
    let task: MuseStandingTask
    let outcome: MuseStandingTaskOutcome?
    let isBusy: Bool
    let onConfirm: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        BubbleWidthLayout(fraction: 0.94, trailing: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text(task.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.foreground)
                Label(task.scheduleHuman, systemImage: "clock")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.foreground)
                Text(task.spec)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                footer.padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.cardBackground, in: .rect(cornerRadius: AppTheme.Radius.card))
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Standing task: \(task.title), \(task.scheduleHuman)")
    }

    @ViewBuilder private var footer: some View {
        if outcome == .alreadySetUp {
            Label("Already set up", systemImage: "checkmark.circle")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Colors.secondaryText)
        } else {
            HStack(spacing: 8) {
                Button(action: onConfirm) {
                    Text("Confirm")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.onTint)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(AppTheme.Colors.tint, in: .capsule)
                }
                Button(action: onNotNow) {
                    Text("Not now")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.foreground)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(AppTheme.Colors.tintSoft, in: .capsule)
                }
                if isBusy { ProgressView().controlSize(.small).padding(.leading, 4) }
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
        }
    }
}

#Preview("MuseStandingTaskCard") {
    let task = MuseStandingTask(
        actionID: "a1", title: "Watch AAPL",
        scheduleHuman: "Every day at 8:00",
        spec: "Check AAPL and tell me when it drops below $180."
    )
    VStack(spacing: 12) {
        MuseStandingTaskCard(task: task, outcome: nil, isBusy: false, onConfirm: {}, onNotNow: {})
        MuseStandingTaskCard(task: task, outcome: .alreadySetUp, isBusy: false, onConfirm: {}, onNotNow: {})
    }
    .padding(.vertical, 16)
    .frame(maxHeight: .infinity)
    .background(AppTheme.Colors.pageBackground)
}
