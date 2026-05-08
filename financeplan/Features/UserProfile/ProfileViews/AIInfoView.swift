//
//  AIInfoView.swift
//  financeplan
//
//  Created by Fernando Correia on 05.03.26.
//

import StockPlanShared
import SwiftUI

struct AIModelIntegrationsInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Why connect an AI model?", systemImage: "sparkles")
                            .typography(.headline, weight: .semibold)

                        Text(
                            "Connect your AI tools so they can work with your Norviq data directly."
                        )
                        .typography(.body)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

                Section {
                    valueRow(
                        title: "Less manual work",
                        detail:
                            "No exporting files, pasting raw data, or writing small scripts just to prepare a question.",
                        systemImage: "wand.and.stars"
                    )
                    valueRow(
                        title: "More reliable answers",
                        detail:
                            "Your assistant can use current market and portfolio data instead of guessing from memory.",
                        systemImage: "checkmark.seal"
                    )
                    valueRow(
                        title: "Cleaner conversations",
                        detail:
                            "Ask focused questions without pasting long API notes or large data responses.",
                        systemImage: "text.bubble"
                    )
                }
                .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
            .navigationTitle("AI Model Integrations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.tint(for: scheme))
                }
            }
        }
    }

    private func valueRow(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .typography(.label, weight: .semibold)
                .foregroundStyle(AppTheme.Colors.tint(for: scheme))
                .frame(width: 28, height: 28)
                .background(AppTheme.Colors.tint(for: scheme).opacity(0.12))
                .clipShape(.rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .typography(.label, weight: .semibold)
                Text(detail)
                    .typography(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
