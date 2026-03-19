//
//  StockDetailsScreen.swift
//  financeplan
//
//  Created by Fernando Correia on 10.03.26.
//

import SwiftUI
import StockPlanShared

struct StockDetailScreen: View {
    let stockId: String
    let initialSymbol: String
    @StateObject private var viewModel = StockDetailsViewModel()
    @State private var showEditValuation = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.details == nil {
                ProgressView("Loading stock...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let errorMessage = viewModel.errorMessage, viewModel.details == nil {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task {
                            await viewModel.load(stockId: stockId)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                content
            }
        }
        .navigationTitle(viewModel.details?.symbol ?? initialSymbol)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditValuation) {
            EditStockValuationView(
                symbol: viewModel.details?.symbol ?? initialSymbol,
                existing: viewModel.valuation
            ) { draft in
                print(
                    """
                    StockDetailScreen.onSave \
                    bearLow=\(draft.bearLow) bearHigh=\(draft.bearHigh) \
                    baseLow=\(draft.baseLow) baseHigh=\(draft.baseHigh) \
                    bullLow=\(draft.bullLow) bullHigh=\(draft.bullHigh) \
                    rationale=\(draft.rationale ?? "<nil>") \
                    targetDate=\(draft.targetDate ?? "<nil>")
                    """
                )
                return await viewModel.saveValuation(draft)
            }
        }
        .task {
            await viewModel.load(stockId: stockId)
        }
    }

    private var content: some View {
        List {
            Section {
                StockValuationCard(
                    valuation: viewModel.valuation,
                    onEditTapped: {
                        showEditValuation = true
                    }
                )
            }

            if let details = viewModel.details {
                Section("Overview") {
                    row(title: "Symbol", value: details.symbol, isSecondary: true)
                    HStack {
                        Text("Shares")
                        Spacer()
                        Text(details.shares, format: .number.precision(.fractionLength(2)))
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Text("Buy price")
                        Spacer()
                        Text(details.buyPrice, format: .currency(code: "USD"))
                            .fontWeight(.semibold)
                    }
                    row(title: "Buy date", value: details.buyDate, isSecondary: true)
                    HStack {
                        Text("Position value")
                        Spacer()
                        Text(details.shares * details.buyPrice, format: .currency(code: "USD"))
                    }
                    if let notes = details.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .foregroundStyle(.secondary)
                            Text(notes)
                        }
                    }
                }
            }

            Section("History") {
                if viewModel.history.isEmpty {
                    Text("No price history available.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(viewModel.history.prefix(10).enumerated()), id: \.offset) { _, point in
                        HStack {
                            Text(point.date)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(point.close, format: .currency(code: "USD"))
                                .monospacedDigit()
                        }
                    }
                }
            }

            Section("Recent News") {
                if viewModel.news.isEmpty {
                    Text("No recent news available.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(viewModel.news.prefix(10).enumerated()), id: \.offset) { _, item in
                        if let url = URL(string: item.url) {
                            Link(destination: url) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Text(item.date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.subheadline.bold())
                                Text(item.date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .refreshable {
            await viewModel.load(stockId: stockId)
        }
    }

    private func row(title: String, value: String, isSecondary: Bool = false) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(isSecondary ? .secondary : .primary)
        }
    }
}
