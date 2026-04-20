//
//  AboutNorviqaView.swift
//  financeplan
//
//  Created by Fernando Correia on 11.04.26.
//

import SwiftUI

struct AboutNorviqaView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
    }

    var body: some View {
        List {
            // Brand Header
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.largeTitle.bold())
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    AppTheme.Colors.tint(for: scheme),
                                    AppTheme.Colors.tint(for: scheme).opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(spacing: 4) {
                        Text("Norviqa")
                            .typography(.hero, weight: .bold)

                        Text("A focused investing workspace for portfolios, watchlists, targets, and market context.")
                            .typography(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Text("v\(appVersion) (\(buildNumber))")
                        .typography(.nano)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            Section("What Norviqa Does") {
                aboutRow(
                    title: "Portfolio clarity",
                    detail: "Track holdings, cost basis, and valuation changes from one place.",
                    systemImage: "chart.pie.fill"
                )
                aboutRow(
                    title: "Research workflow",
                    detail: "Keep watchlists, stock insights, targets, and notes close to your decisions.",
                    systemImage: "doc.text.magnifyingglass"
                )
                aboutRow(
                    title: "Security first",
                    detail: "MFA, device authentication, and local app-lock controls protect access to your account.",
                    systemImage: "lock.shield.fill"
                )
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Legal
            Section("Legal") {
                if let privacyURL = URL(string: "https://norviqa.com/privacy") {
                    Link(destination: privacyURL) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                    .foregroundStyle(.primary)
                }

                if let termsURL = URL(string: "https://norviqa.com/terms") {
                    Link(destination: termsURL) {
                        Label("Terms of Service", systemImage: "doc.text.fill")
                    }
                    .foregroundStyle(.primary)
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Connect
            Section("Connect") {
                socialButton("Follow on Instagram", systemImage: "camera", url: "https://instagram.com/norviqa")

                if let xURL = URL(string: "https://x.com/norviqa") {
                    Link(destination: xURL) {
                        Label("Follow on X", systemImage: "x.circle")
                    }
                    .foregroundStyle(.primary)
                }

                if let discordURL = URL(string: "https://discord.gg/norviqa") {
                    Link(destination: discordURL) {
                        Label("Join Discord", systemImage: "bubble.left.and.bubble.right")
                    }
                    .foregroundStyle(.primary)
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
        .navigationTitle("About Norviqa")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func aboutRow(title: String, detail: String, systemImage: String) -> some View {
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

    @ViewBuilder
    private func socialButton(_ title: LocalizedStringKey, systemImage: String, url: String) -> some View {
        if let destination = URL(string: url) {
            Button {
                openURL(destination)
            } label: {
                Label(title, systemImage: systemImage)
            }
            .foregroundStyle(.primary)
        }
    }
}
