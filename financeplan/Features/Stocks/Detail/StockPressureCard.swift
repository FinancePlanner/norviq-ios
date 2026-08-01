import Charts
import Factory
import SwiftUI

/// Buying/selling pressure card for the stock overview tab: temperature
/// thermometer, relative-volume history chart, and insider activity.
/// Self-loading — failures collapse the card instead of erroring the tab.
struct StockPressureCard: View {
  let symbol: String
  @State private var viewModel = StockPressureViewModel()

  var body: some View {
    Group {
      if let pressure = viewModel.pressure {
        GlassCard {
          VStack(alignment: .leading, spacing: 14) {
            header(pressure)
            thermometer(pressure)
            statRow(pressure)
            if !pressure.history.isEmpty {
              historyChart(pressure)
            }
            if let insider = pressure.insider {
              insiderSection(insider)
            }
          }
        }
      } else if viewModel.isLoading {
        GlassCard {
          HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Reading trading pressure…")
              .typography(.small)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
    .task(id: symbol) {
      await viewModel.load(symbol: symbol)
    }
  }

  private func header(_ pressure: MarketPressureResponse) -> some View {
    HStack {
      Text("Trading pressure")
        .typography(.small, weight: .semibold)
      Spacer()
      Text(pressure.label.capitalized)
        .font(.caption.weight(.bold))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(PressurePalette.tone(pressure.temperature).opacity(0.15), in: Capsule())
        .foregroundStyle(PressurePalette.tone(pressure.temperature))
    }
  }

  private func thermometer(_ pressure: MarketPressureResponse) -> some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 0) {
        Text("\(pressure.temperature, specifier: "%.0f")")
          .font(.system(size: 34, weight: .bold, design: .rounded))
          .contentTransition(.numericText(value: pressure.temperature))
        Text("/100")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
      VStack(spacing: 3) {
        GeometryReader { proxy in
          ZStack(alignment: .leading) {
            Capsule()
              .fill(
                LinearGradient(
                  colors: [PressurePalette.selling, Color(.systemGray4), PressurePalette.buying],
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
            Rectangle()
              .fill(.secondary.opacity(0.5))
              .frame(width: 1)
              .offset(x: proxy.size.width / 2)
            Circle()
              .fill(.primary)
              .stroke(.background, lineWidth: 3)
              .frame(width: 18, height: 18)
              .offset(x: proxy.size.width * pressure.temperature / 100 - 9)
              .appAnimation(AppMotion.state, value: pressure.temperature)
          }
        }
        .frame(height: 12)
        HStack {
          Text("Selling")
          Spacer()
          Text("Buying")
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.tertiary)
        .textCase(.uppercase)
      }
    }
  }

  private func statRow(_ pressure: MarketPressureResponse) -> some View {
    HStack(spacing: 8) {
      statTile(
        title: "Rel. volume",
        value: String(format: "%.2f×", pressure.volume.relative),
        emphasized: pressure.volume.relative >= 1.5
      )
      statTile(
        title: "Today / avg",
        value: "\(compactVolume(pressure.volume.today)) / \(compactVolume(pressure.volume.average30d))",
        emphasized: false
      )
      statTile(
        title: "Day move",
        value: String(format: "%+.2f%%", pressure.volume.changePct),
        emphasized: false,
        tint: pressure.volume.changePct >= 0 ? PressurePalette.buying : PressurePalette.selling
      )
    }
  }

  private func statTile(title: String, value: String, emphasized: Bool, tint: Color? = nil) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.footnote.weight(.semibold).monospacedDigit())
        .foregroundStyle(tint ?? (emphasized ? .accentColor : .primary))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))
  }

  private func historyChart(_ pressure: MarketPressureResponse) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("VOLUME VS 30-SESSION AVERAGE")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
      Chart(pressure.history) { point in
        BarMark(
          x: .value("Date", point.date),
          y: .value("Relative", min(point.relativeVolume, 3))
        )
        .foregroundStyle(PressurePalette.bar(point.relativeVolume))
        .cornerRadius(1.5)
      }
      .chartYScale(domain: 0 ... 3)
      .chartXAxis(.hidden)
      .chartYAxis {
        AxisMarks(values: [1.0]) { _ in
          AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3]))
          AxisValueLabel("1×").font(.caption2)
        }
      }
      .frame(height: 72)
    }
  }

  private func insiderSection(_ insider: MarketPressureInsider) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Divider()
      HStack {
        Text("INSIDERS · \(insider.windowDays)D")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        Text("\(insider.netShares < 0 ? "net selling" : "net buying") \(compactVolume(abs(insider.netShares)))")
          .font(.caption2.weight(.bold))
          .foregroundStyle(insider.netShares < 0 ? PressurePalette.selling : PressurePalette.buying)
      }
      Text("\(insider.buyCount) buys · \(insider.sellCount) sells")
        .font(.caption)
        .foregroundStyle(.secondary)
      ForEach(insider.notable.prefix(3)) { trade in
        HStack(spacing: 8) {
          Circle()
            .fill(trade.side == "buy" ? PressurePalette.buying : PressurePalette.selling)
            .frame(width: 6, height: 6)
          Text(trade.name)
            .font(.caption)
            .lineLimit(1)
          Spacer()
          Text("\(compactVolume(trade.shares)) sh")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
          Text(trade.date)
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }
    }
  }

  private func compactVolume(_ value: Double) -> String {
    let abs = Swift.abs(value)
    switch abs {
    case 1e9...: return String(format: "%.1fB", value / 1e9)
    case 1e6...: return String(format: "%.1fM", value / 1e6)
    case 1e3...: return String(format: "%.1fK", value / 1e3)
    default: return String(format: "%.0f", value)
    }
  }
}

enum PressurePalette {
  static let buying = Color(red: 0.03, green: 0.60, blue: 0.51)
  static let selling = Color(red: 0.95, green: 0.21, blue: 0.27)

  static func tone(_ temperature: Double) -> Color {
    switch temperature {
    case ..<40: selling
    case ..<60: Color.secondary
    default: buying
    }
  }

  static func bar(_ relative: Double) -> Color {
    switch relative {
    case 1.5...: .accentColor
    case ..<0.7: Color(.systemGray4)
    default: Color(.systemGray2)
    }
  }
}

@MainActor
@Observable
final class StockPressureViewModel {
  var pressure: MarketPressureResponse?
  var isLoading = false

  private let marketDataService: any MarketDataServicing

  init(marketDataService: any MarketDataServicing = Container.shared.marketDataService()) {
    self.marketDataService = marketDataService
  }

  func load(symbol: String) async {
    guard pressure?.symbol != symbol else { return }
    isLoading = true
    defer { isLoading = false }
    pressure = try? await marketDataService.fetchMarketPressure(symbol: symbol)
  }
}
