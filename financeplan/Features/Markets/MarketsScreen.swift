import SwiftUI

/// Finviz-style markets overview: index strip, sector heat-map treemap,
/// top gainers/losers, and market headlines.
struct MarketsScreen: View {
  @Environment(\.colorScheme) private var scheme
  @State private var viewModel = MarketsViewModel()
  @State private var newsViewModel = MacroViewModel()

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          VigilPageHeader(
            watch: .wealth,
            title: "Markets"
          )

          if let overview = viewModel.overview {
            if !overview.indices.isEmpty {
              indexStrip(overview.indices)
            }
            if !overview.heatmap.isEmpty {
              MarketsHeatmapCard(tiles: overview.heatmap)
            }
            if !overview.gainers.isEmpty || !overview.losers.isEmpty {
              MarketsMoversCard(gainers: overview.gainers, losers: overview.losers)
            }
            if !newsViewModel.news.isEmpty {
              MacroNewsCard(news: newsViewModel.news)
            }
            Text("As of \(overview.asOf)")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          } else if viewModel.isLoading {
            ProgressView("Loading markets…")
              .frame(maxWidth: .infinity)
              .padding(.top, 80)
          } else {
            ContentUnavailableView(
              "Markets are warming up",
              systemImage: "square.grid.3x3",
              description: Text(viewModel.errorMessage ?? "Market data is temporarily unavailable. Pull to refresh.")
            )
          }
        }
        .padding()
      }
      .vigilScreenBackground()
      .vigilNavigationTitle("Markets")
      .vigilInlineNavigationBar()
      .refreshable {
        await viewModel.load()
      }
      .task {
        if viewModel.overview == nil {
          await viewModel.load()
        }
        if newsViewModel.news.isEmpty {
          await newsViewModel.load(country: "US")
        }
      }
    }
  }

  private func indexStrip(_ indices: [MarketIndexQuote]) -> some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
      ForEach(indices) { index in
        VStack(alignment: .leading, spacing: 4) {
          Text(index.isProxy ? "\(index.label) (\(index.symbol))" : index.label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Text(index.price, format: .number.precision(.fractionLength(2)))
            .font(.headline.monospacedDigit())
          Text("\(index.changePct >= 0 ? "+" : "")\(index.changePct, specifier: "%.2f")%")
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(index.changePct >= 0 ? MarketsPalette.gain : MarketsPalette.loss)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
      }
    }
  }
}

enum MarketsPalette {
  static let gain = Color(red: 0.03, green: 0.60, blue: 0.51)
  static let loss = Color(red: 0.95, green: 0.21, blue: 0.27)
  static let neutral = Color(red: 0.25, green: 0.27, blue: 0.33)

  /// Finviz-style red→neutral→green ramp clamped at ±3%.
  static func heat(_ changePct: Double) -> Color {
    let t = max(-1, min(1, changePct / 3))
    let target = t >= 0 ? gain : loss
    return neutral.blended(with: target, fraction: abs(t))
  }
}

extension Color {
  func blended(with other: Color, fraction: Double) -> Color {
    let from = UIColor(self)
    let to = UIColor(other)
    var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
    var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
    from.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
    to.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
    let f = CGFloat(max(0, min(1, fraction)))
    return Color(
      red: fr + (tr - fr) * f,
      green: fg + (tg - fg) * f,
      blue: fb + (tb - fb) * f
    )
  }
}

// MARK: - Heat-map card

struct MarketsHeatmapCard: View {
  let tiles: [MarketHeatmapTile]
  @State private var selected: MarketHeatmapTile?

  private var sortedTiles: [MarketHeatmapTile] {
    tiles.sorted { $0.marketCap > $1.marketCap }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Heat-map")
          .font(.headline)
        Spacer()
        Text("size = cap · color = today")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      GeometryReader { proxy in
        let items = sortedTiles
        let frames = SquarifiedTreemap.frames(
          weights: items.map(\.marketCap),
          in: CGRect(origin: .zero, size: proxy.size)
        )
        ZStack(alignment: .topLeading) {
          ForEach(Array(items.enumerated()), id: \.element.id) { index, tile in
            let frame = frames[index]
            MarketsHeatTile(tile: tile, frame: frame)
              .onTapGesture { selected = tile }
          }
        }
      }
      .frame(height: 380)
      .clipShape(RoundedRectangle(cornerRadius: 12))

      if let selected {
        HStack(spacing: 6) {
          Text(selected.symbol).font(.caption.weight(.bold).monospaced())
          Text(selected.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
          Spacer()
          Text("\(selected.changePct >= 0 ? "+" : "")\(selected.changePct, specifier: "%.2f")%")
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(selected.changePct >= 0 ? MarketsPalette.gain : MarketsPalette.loss)
          Text("· \(selected.sector)")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .transition(.opacity)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .appAnimation(AppMotion.state, value: selected)
  }
}

private struct MarketsHeatTile: View {
  let tile: MarketHeatmapTile
  let frame: CGRect

  var body: some View {
    RoundedRectangle(cornerRadius: 2)
      .fill(MarketsPalette.heat(tile.changePct))
      .overlay {
        if frame.width > 34, frame.height > 24 {
          VStack(spacing: 1) {
            Text(tile.symbol)
              .font(.system(size: min(13, max(8, frame.width / 5)), weight: .bold))
            if frame.height > 40 {
              Text("\(tile.changePct >= 0 ? "+" : "")\(tile.changePct, specifier: "%.1f")%")
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
      .accessibilityLabel(Text(verbatim: "\(tile.symbol), \(tile.changePct >= 0 ? "up" : "down") \(String(format: "%.2f", abs(tile.changePct))) percent"))
  }
}

// MARK: - Movers card

struct MarketsMoversCard: View {
  let gainers: [MarketMover]
  let losers: [MarketMover]
  @State private var showingGainers = true

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Movers")
          .font(.headline)
        Spacer()
        Picker("Movers", selection: $showingGainers) {
          Text("Gainers").tag(true)
          Text("Losers").tag(false)
        }
        .pickerStyle(.segmented)
        .frame(width: 180)
      }

      ForEach((showingGainers ? gainers : losers).prefix(8)) { mover in
        HStack(spacing: 10) {
          Text(mover.symbol)
            .font(.subheadline.weight(.bold).monospaced())
            .frame(width: 64, alignment: .leading)
          Text(mover.name)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Spacer()
          VStack(alignment: .trailing, spacing: 1) {
            Text(mover.price, format: .number.precision(.fractionLength(2)))
              .font(.subheadline.monospacedDigit())
            Text("\(mover.changePct >= 0 ? "+" : "")\(mover.changePct, specifier: "%.2f")%")
              .font(.caption.weight(.semibold).monospacedDigit())
              .foregroundStyle(mover.changePct >= 0 ? MarketsPalette.gain : MarketsPalette.loss)
          }
        }
        .padding(.vertical, 3)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
}
