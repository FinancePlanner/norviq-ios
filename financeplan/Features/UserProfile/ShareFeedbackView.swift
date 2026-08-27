//
//  ShareFeedbackView.swift
//  financeplan
//
//  Created by Fernando Correia on 11.04.26.
//

import SwiftUI

struct ShareFeedbackView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var feedbackTopic: FeedbackTopic?

    var body: some View {
        List {
            Section {
                VigilPageHeader(
                    watch: .settings("Feedback"),
                    title: "Share Feedback",
                    subtitle: "Bug reports, ideas, and product thoughts"
                )
                .listRowBackground(Color.clear)
            }

            // Header
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.Colors.tint(for: scheme))

                    Text("Your feedback shapes Norviq")
                        .typography(.label, weight: .semibold)
                        .multilineTextAlignment(.center)

                    Text("Whether it's a bug, a feature idea, or just a thought — we'd love to hear from you.")
                        .typography(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Direct Feedback
            Section("Reach Out") {
                Button {
                    feedbackTopic = .general
                } label: {
                    Label("Send Feedback", systemImage: "envelope.fill")
                }
                .foregroundStyle(.primary)

                Button {
                    feedbackTopic = .feature
                } label: {
                    Label("Request a Feature", systemImage: "sparkles")
                }
                .foregroundStyle(.primary)
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
        }
        .vigilListChrome()
        .vigilScreenBackground()
        .vigilNavigationTitle("Share Feedback")
        .vigilInlineNavigationBar()
        .sheet(item: $feedbackTopic) { topic in
            FeedbackSheet(initialTopic: topic.title)
        }
    }
}

private enum FeedbackTopic: Identifiable {
    case general
    case feature

    var id: String { title }

    var title: String {
        switch self {
        case .general:
            return "General Feedback"
        case .feature:
            return "Feature Request"
        }
    }
}
