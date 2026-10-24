//
//  ConnectView.swift
//  financeplan
//
//  Created by Fernando Correia on 05.03.26.
//

import Factory
import StockPlanShared
import SwiftUI

struct ConnectView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL
    @Injected(\.analytics) private var analytics

    var body: some View {
        List {
            Section {
                VigilPageHeader(
                    watch: .settings("Connect"),
                    title: "Connect",
                    subtitle: "Community and social channels"
                )
                .listRowBackground(Color.clear)
            }

            Section {
                socialButton(
                    LocalizedStringKey("Follow on Instagram"), systemImage: "camera",
                    url: "https://instagram.com/norviqplan")
                socialButton(
                    LocalizedStringKey("Follow on X"), systemImage: "x.circle",
                    url: "https://x.com/NorviqPlanner")
                socialButton(
                    LocalizedStringKey("Follow on TikTok"), systemImage: "music.note",
                    url: "https://tiktok.com/@norviqplan")
                Button {
                    analytics.track("discord_link_clicked", properties: ["surface": "settings"])
                    openURL(Constants.Norviq.discordURL)
                } label: {
                    Label(LocalizedStringKey("Join us on Discord"), systemImage: "bubble.left.and.bubble.right")
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
        }
        .vigilListChrome()
        .vigilScreenBackground()
        .vigilNavigationTitle(LocalizedStringKey("Connect"))
        .vigilInlineNavigationBar()
    }

    @ViewBuilder
    private func socialButton(_ title: LocalizedStringKey, systemImage: String, url: String)
        -> some View
    {
        if let destination = URL(string: url) {
            Button {
                openURL(destination)
            } label: {
                Label(title, systemImage: systemImage)
            }
        }
    }
}
