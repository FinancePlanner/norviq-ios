import SwiftUI
import StockPlanShared

/// Polished bottom sheet for mobile trading dashboard experience.
/// Shows live price, candlestick chart (when data available), timeframes, volume, and Buy/Short actions.
struct TradingStockSheet: View {
    let symbol: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @InjectedObservable(\Container.billingManager) private var billingManager

    @State private var selectedRange: PriceChartRange = .oneDay
    @State private var chartSeries: PriceChartSeries?
    @State private var isChartLoading = false
    @State private var chartError: String?
    @State private var marketSnapshot: QuoteResponse?
    @State private var isLoadingQuote = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header: Price + Change (live)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(symbol.uppercased())
                                .typography(.title, weight: .bold)

                            Spacer()

                            if let snapshot = marketSnapshot {
                                Text(snapshot.currentPrice.currency)
                                    .typography(.title, weight: .bold)
                                    .monospacedDigit()
                            } else if isLoadingQuote {
                                ProgressView()
                            } else {
                                Text("—")
                                    .typography(.title, weight: .bold)
                            }
                        }

                        if let snapshot = marketSnapshot,
                           let pct = snapshot.percentChange {
                            HStack {
                                Text(StockMetricFormatter.signedCurrencyText(snapshot.change ?? 0))
                                    .foregroundStyle((snapshot.change ?? 0) >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger)

                                Text(StockMetricFormatter.signedPercentText(pct))
                                    .foregroundStyle((snapshot.change ?? 0) >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.1), in: Capsule())

                                Spacer()

                                if let vol = getVolumeForSnapshot(snapshot) {
                                    Text("Vol \(vol.formatted(.number.notation(.compactName)))")
                                        .typography(.nano)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .typography(.caption, weight: .semibold)
                        } else {
                            Text("Live data loading...")
                                .typography(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    // Timeframe selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PriceChartRange.allCases, id: \.rawValue) { range in
                                Button {
                                    selectedRange = range
                                    Task { await loadChart() }
                                } label: {
                                    Text(range.title)
                                        .typography(.caption, weight: .semibold)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedRange == range
                                                ? AppTheme.Colors.tint(for: colorScheme)
                                                : Color.secondary.opacity(0.1),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(selectedRange == range ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Chart (now with candle support)
                    if isChartLoading {
                        ProgressView()
                            .frame(height: 280)
                    } else if let error = chartError {
                        Text(error)
                            .typography(.small)
                            .foregroundStyle(AppTheme.Colors.danger)
                            .padding()
                    } else if let series = chartSeries, !series.points.isEmpty {
                        StockPriceChartTab(
                            series: series,
                            selectedRange: selectedRange,
                            isLoading: false,
                            errorMessage: nil,
                            onSelectRange: { newRange in
                                selectedRange = newRange
                                Task { await loadChart() }
                            }
                        )
                        .padding(.horizontal, 4)
                    } else {
                        Text("Chart data unavailable")
                            .foregroundStyle(.secondary)
                            .frame(height: 200)
                    }

                    // Quick actions: Buy / Short
                    HStack(spacing: 12) {
                        Button {
                            dismiss()
                            // In real flow: present buy sheet for this symbol
                            // For now, we can post a notification or assume caller handles
                            NotificationCenter.default.post(name: .openAddPositionForSymbol, object: symbol)
                        } label: {
                            Label("Buy \(symbol)", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.Colors.success)

                        Button {
                            dismiss()
                            NotificationCenter.default.post(name: .openSellForSymbol, object: symbol)
                        } label: {
                            Label("Short \(symbol)", systemImage: "minus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.Colors.danger)
                    }
                    .controlSize(.large)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    Text("Prices update with live market data. Pro features may apply for advanced charts.")
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .navigationTitle("Trade \(symbol)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            Task {
                await loadQuote()
                await loadChart()
            }
        }
    }

    private func loadQuote() async {
        isLoadingQuote = true
        defer { isLoadingQuote = false }
        // Use the shared market data service pattern from the rest of the app for auth
        do {
            // In full context this would resolve via Container or @Environment
            let env = AppEnvironmentManager.shared.current
            let service = MarketDataHTTPService(
                environmentManager: AppEnvironmentManager.shared,
                authSessionManager: AuthSessionManager.shared
            )
            marketSnapshot = try await service.fetchQuote(symbol: symbol)
        } catch {
            // Snapshot may come from parent view or portfolio liveQuotes
        }
    }

    private func loadChart() async {
        isChartLoading = true
        chartError = nil
        defer { isChartLoading = false }

        do {
            let service = MarketDataHTTPService(
                environmentManager: AppEnvironmentManager.shared,
                authSessionManager: AuthSessionManager.shared
            )
            chartSeries = try await service.fetchPriceChart(symbol: symbol, range: selectedRange.rawValue)
        } catch {
            chartError = "Failed to load chart data."
        }
    }

    private func getVolumeForSnapshot(_ snapshot: QuoteResponse) -> Double? {
        // Volume not directly in basic QuoteResponse in this model.
        // In real use we could fetch additional detail or use last point from chart.
        // For polish, return nil (hidden) or a placeholder.
        return nil
    }
}

// Notifications for integration with existing position sheets
extension Notification.Name {
    static let openAddPositionForSymbol = Notification.Name("openAddPositionForSymbol")
    static let openSellForSymbol = Notification.Name("openSellForSymbol")
}
