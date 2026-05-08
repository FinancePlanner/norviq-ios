//
//  ConnectView.swift
//  financeplan
//
//  Created by Fernando Correia on 05.03.26.
//

import StockPlanShared
import SwiftUI

struct ConnectView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
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
                socialButton(
                    LocalizedStringKey("Join Discord"), systemImage: "bubble.left.and.bubble.right",
                    url: "https://discord.gg/3QVkas3rH")
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
        .navigationTitle(LocalizedStringKey("Connect"))
        .navigationBarTitleDisplayMode(.inline)
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
