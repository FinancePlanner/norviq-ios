//
//  ShareFeedbackView.swift
//  financeplan
//
//  Created by Fernando Correia on 11.04.26.
//

import StoreKit
import SwiftUI

struct ShareFeedbackView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.requestReview) private var requestReview
    @State private var feedbackTopic: FeedbackTopic?

    var body: some View {
        List {
            // Header
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.Colors.tint(for: scheme))

                    Text("Your feedback shapes Norviqa")
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

            // App Store Review
            Section {
                Button {
                    requestReview()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rate on App Store")
                                .typography(.body, weight: .semibold)
                                .foregroundStyle(.primary)
                            Text("Takes just a second and helps us a lot")
                                .typography(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                }
                .buttonStyle(.plain)
            } footer: {
                Text("App Store ratings help other investors discover Norviqa.")
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
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
        .navigationTitle("Share Feedback")
        .navigationBarTitleDisplayMode(.inline)
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
