//
//  AboutNorviqaView.swift
//  financeplan
//
//  Created by Fernando Correia on 11.04.26.
//

import SwiftUI

struct AboutNorviqaView: View {
    @Environment(\.colorScheme) private var scheme

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
                        .font(.system(size: 56))
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

                        Text("Smart investing, simplified.")
                            .typography(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("v\(appVersion) (\(buildNumber))")
                        .typography(.nano)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
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

            // Footer
            Section {
                Text("Made with ❤️ for investors everywhere")
                    .typography(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
        .navigationTitle("About Norviqa")
        .navigationBarTitleDisplayMode(.inline)
    }
}
