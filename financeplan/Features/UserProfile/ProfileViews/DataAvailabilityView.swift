//
//  DataAvailabilityView.swift
//  financeplan
//
//  Created by Fernando Correia on 05.03.26.
//

import StockPlanShared
import SwiftUI

struct DataAvailabilityView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Market data coverage", systemImage: "chart.line.uptrend.xyaxis")
                        .typography(.label, weight: .semibold)

                    Text(
                        "Some analysis, statements, consensus, and forecast data depends on the market data coverage currently connected to Norviq."
                    )
                    .typography(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            Section {
                coverageRow(
                    title: "Free data coverage",
                    detail: "Available for the supported symbol list below."
                )
                coverageRow(
                    title: "Starter data coverage",
                    detail: "Available for US exchanges."
                )
                coverageRow(
                    title: "Premium data coverage",
                    detail: "Available for US, UK, and Canada exchanges."
                )
            } header: {
                Text("Data Coverage")
            } footer: {
                Text(
                    "Market data coverage is separate from your Norviq subscription. If a data source does not cover a symbol or date range, the app keeps the rest of the stock page usable."
                )
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            Section("App Subscription Limits") {
                Text(
                    "Norviq subscription limits control app features such as portfolio capacity, imports, alerts, reports, and advanced research access."
                )
                .typography(.caption)
                .foregroundStyle(.secondary)
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            Section {
                DisclosureGroup("Supported symbols on current free data coverage") {
                    Text(FMPFreeTierCoverage.supportedSymbolsDisplay)
                        .typography(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.vertical, 6)
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
        .navigationTitle("Data Availability")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func coverageRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .typography(.label, weight: .semibold)
            Text(detail)
                .typography(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
