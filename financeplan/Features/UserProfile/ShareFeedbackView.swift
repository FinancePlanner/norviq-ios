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

    var body: some View {
        List {
            // Header
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.system(size: 36))
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
                if let feedbackURL = URL(string: "mailto:feedback@norviqa.com?subject=Norviqa%20Feedback") {
                    Link(destination: feedbackURL) {
                        Label("Send Feedback", systemImage: "envelope.fill")
                    }
                    .foregroundStyle(.primary)
                }

                if let featureURL = URL(string: "mailto:feedback@norviqa.com?subject=Feature%20Request") {
                    Link(destination: featureURL) {
                        Label("Request a Feature", systemImage: "sparkles")
                    }
                    .foregroundStyle(.primary)
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
        .navigationTitle("Share Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }
}
