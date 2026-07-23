//
//  AssistantCommandViews.swift
//  financeplan
//
//  Shared UI for slash commands: first-run suggestion chips and the composer
//  autocomplete list. Used by both assistant surfaces.
//

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
