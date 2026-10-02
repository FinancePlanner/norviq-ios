import StockPlanShared
import SwiftUI

// MARK: - Timeframe picker

/// 1D … All. A row of capsules rather than a segmented Picker because
/// windows the data source cannot answer must be individually disabled.
struct CryptoTimeframePicker: View {
    @ObservedObject var viewModel: CryptoMarketsViewModel
    var onDark = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(CryptoMarketsTimeframe.allCases, id: \.self) { option in
                let isSelected = option == viewModel.timeframe
                Button {
                    Task { await viewModel.select(option) }
                } label: {
                    Text(option.displayTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : (onDark ? .white.opacity(0.85) : .primary))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? AppTheme.Colors.tint(for: colorScheme) : Color.secondary.opacity(onDark ? 0.25 : 0.10),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isEnabled(option))
                .opacity(viewModel.isEnabled(option) ? 1 : 0.35)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

// MARK: - Heatmap

struct CryptoHeatmapCard: View {
    let response: CryptoMarketsResponse
    @State private var selected: CryptoMarketCoin?

    private var tiles: [CryptoMarketCoin] {
        response.coins
            .filter { ($0.marketCap ?? 0) > 0 && $0.changePct != nil }
            .sorted { ($0.marketCap ?? 0) > ($1.marketCap ?? 0) }
    }

    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Heat-map").font(.headline)
                    Spacer()
                    Text("size = cap · color = \(response.timeframe.displayTitle)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                GeometryReader { proxy in
                    let items = tiles
                    let frames = SquarifiedTreemap.frames(
                        weights: items.map { $0.marketCap ?? 0 },
                        in: CGRect(origin: .zero, size: proxy.size)
                    )
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, coin in
                            CryptoHeatTile(coin: coin, frame: frames[index], response: response)
                                .onTapGesture { selected = coin }
                        }
                    }
                }
                .frame(height: 340)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if let selected {
                    HStack(spacing: 6) {
                        Text(selected.symbol).font(.caption.weight(.bold).monospaced())
                        Text(selected.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        if let pct = selected.changePct {
                            Text(formatCryptoPercent(pct))
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(pct >= 0 ? MarketsPalette.gain : MarketsPalette.loss)
                        }
                        Text("· \(selected.sector)").font(.caption2).foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }
            }
        }
        .appAnimation(AppMotion.state, value: selected)
    }
}

private struct CryptoHeatTile: View {
    let coin: CryptoMarketCoin
    let frame: CGRect
    let response: CryptoMarketsResponse

    private var pct: Double { coin.changePct ?? 0 }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(CryptoHeatColor.color(pct, scaleMax: response.colorScaleMaxPct, mode: response.colorMode))
            .overlay {
                if frame.width > 34, frame.height > 24 {
                    VStack(spacing: 1) {
                        Text(coin.symbol)
                            .font(.system(size: min(13, max(8, frame.width / 5)), weight: .bold))
                        if frame.height > 40 {
                            Text(formatCryptoPercent(pct, digits: 1))
                                .font(.system(size: min(10, max(7, frame.width / 7)), weight: .semibold))
                                .opacity(0.9)
                        }
                    }
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(1)
                }
            }
            .frame(width: max(frame.width - 1, 1), height: max(frame.height - 1, 1))
            .position(x: frame.midX, y: frame.midY)
            .accessibilityLabel(Text(verbatim: "\(coin.name), \(formatCryptoPercent(pct))"))
    }
}

// MARK: - Performers

struct CryptoPerformersCard: View {
    let response: CryptoMarketsResponse
    @State private var showingBest = true

    private var bestTitle: String { response.timeframe == .allTime ? "Nearest ATH" : "Top" }
    private var worstTitle: String { response.timeframe == .allTime ? "Furthest" : "Worst" }

    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Performers · \(response.timeframe.displayTitle)").font(.headline)
                    Spacer()
                    Picker("Performers", selection: $showingBest) {
                        Text(bestTitle).tag(true)
                        Text(worstTitle).tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                }
                let rows = showingBest ? response.gainers : response.losers
                if rows.isEmpty {
                    Text("No coins moved this way over \(response.timeframe.displayTitle).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rows) { coin in
                        CryptoMarketCoinRow(coin: coin, value: coin.changePct.map { formatCryptoPercent($0) })
                    }
                }
            }
        }
    }
}

// MARK: - All-time-high board

struct CryptoAthBoardCard: View {
    let board: CryptoAthBoard

    private enum List: String, CaseIterable, Identifiable {
        case recent = "New highs", near = "Near high", deepest = "Furthest"
        var id: String { rawValue }
    }

    @State private var list: List = .recent

    private var rows: [CryptoMarketCoin] {
        switch list {
        case .recent: board.recentAths
        case .near: board.nearAth
        case .deepest: board.deepestDrawdowns
        }
    }

    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("All-time highs").font(.headline)
                Picker("All-time highs", selection: $list) {
                    ForEach(List.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                if rows.isEmpty {
                    Text(list == .recent ? "No coin set a new high in the last 30 days." : "No data right now.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rows) { coin in
                        CryptoMarketCoinRow(
                            coin: coin,
                            value: coin.athChangePct.map { String(format: "%.1f%%", $0) },
                            caption: Self.caption(for: coin),
                            tint: .primary
                        )
                    }
                }
            }
        }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static func caption(for coin: CryptoMarketCoin) -> String? {
        var parts: [String] = []
        if let raw = coin.athDate, let date = ISO8601DateFormatter.cryptoMarkets.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) {
            parts.append("High \(dayFormatter.string(from: date))")
        }
        if let fromLow = coin.atlChangePct, fromLow >= 1000 {
            parts.append("\(Int((1 + fromLow / 100).rounded()).formatted())x from low")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

extension ISO8601DateFormatter {
    /// CoinGecko timestamps carry fractional seconds.
    static let cryptoMarkets: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

// MARK: - Row

/// Ticker, name, price and one right-hand figure; pushes the detail screen
/// when FMP carries the coin.
struct CryptoMarketCoinRow: View {
    let coin: CryptoMarketCoin
    let value: String?
    var caption: String?
    /// Overrides the gain/loss colour, for figures that are not a move.
    var tint: Color?

    var body: some View {
        if let route = coin.detailRoute {
            NavigationLink(value: route) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var valueColor: Color {
        if let tint { return tint }
        guard let pct = coin.changePct else { return .primary }
        return pct >= 0 ? MarketsPalette.gain : MarketsPalette.loss
    }

    private var content: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(coin.symbol).font(.subheadline.weight(.semibold).monospaced())
                Text(caption ?? coin.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let value {
                    Text(value)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(valueColor)
                }
                Text(coin.price.formatted(.currency(code: "USD").precision(.significantDigits(2...6))))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
