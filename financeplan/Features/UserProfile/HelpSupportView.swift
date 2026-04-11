//
//  HelpSupportView.swift
//  financeplan
//
//  Created by Fernando Correia on 11.04.26.
//

import SwiftUI

struct HelpSupportView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        List {
            // Getting Started
            Section("Getting Started") {
                Label("How Norviqa Works", systemImage: "lightbulb.fill")
                Label("Import Guide", systemImage: "square.and.arrow.down")
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Contact Us
            Section {
                if let mailURL = URL(string: "mailto:support@norviqa.com") {
                    Link(destination: mailURL) {
                        Label("Email Support", systemImage: "envelope.fill")
                    }
                    .foregroundStyle(.primary)
                }

                HStack {
                    Label("Response Time", systemImage: "clock.fill")
                    Spacer()
                    Text("~24 hours")
                        .typography(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Contact Us")
            } footer: {
                Text("We typically respond within one business day.")
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Resources
            Section("Resources") {
                if let faqURL = URL(string: "https://norviqa.com/faq") {
                    Link(destination: faqURL) {
                        Label("Frequently Asked Questions", systemImage: "text.book.closed.fill")
                    }
                    .foregroundStyle(.primary)
                }

                if let discordURL = URL(string: "https://discord.gg/norviqa") {
                    Link(destination: discordURL) {
                        Label("Community Discord", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                    .foregroundStyle(.primary)
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}
