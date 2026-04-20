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
            Section("Getting Started") {
                supportGuideRow(
                    title: "Portfolio import",
                    detail: "Import CSV holdings from Portfolio, preview rows, then commit when everything looks right.",
                    systemImage: "square.and.arrow.down"
                )
                supportGuideRow(
                    title: "Price target alerts",
                    detail: "Create bull, base, or bear targets from a stock detail screen and enable alerts in Settings.",
                    systemImage: "bell.badge.fill"
                )
                supportGuideRow(
                    title: "Watchlist tracking",
                    detail: "Save tickers to a watchlist and use notes to keep research context close to the quote.",
                    systemImage: "list.bullet.rectangle"
                )
                supportGuideRow(
                    title: "Account security",
                    detail: "Use MFA at sign-in, Face ID app lock, and a local Security Code for protected access.",
                    systemImage: "lock.shield.fill"
                )
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

    private func supportGuideRow(title: String, detail: String, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .typography(.body, weight: .semibold)
                    .foregroundStyle(.primary)
                Text(detail)
                    .typography(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 3)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.Colors.tint(for: scheme))
        }
    }
}
