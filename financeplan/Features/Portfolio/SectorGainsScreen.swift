import Charts
import StockPlanShared
import SwiftUI

@MainActor
struct SectorGainsScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var viewModel = SectorGainsViewModel()

  private var sectors: [SectorGainItem] {
    viewModel.response?.sectors ?? []
  }

  private var totalUnrealizedPnl: Double {
    viewModel.response?.totalUnrealizedPnl ?? 0
  }

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.response == nil {
        SectorGainsSkeletonView()
      } else if let error = viewModel.errorMessage, viewModel.response == nil {
        ContentUnavailableView {
          Label("Unable to Load Sector Gains", systemImage: "exclamationmark.triangle")
        } description: {
          Text(error)
        } actions: {
          Button("Retry") {
            Task { await viewModel.load(force: true) }
          }
          .buttonStyle(.borderedProminent)
        }
      } else if sectors.isEmpty {
        ContentUnavailableView {
          Label("No Sector Gains Yet", systemImage: "chart.bar.fill")
        } description: {
          Text("Add holdings to see unrealized gains grouped by sector.")
        }
      } else {
        content
      }
    }
    .navigationTitle("Sector Gains")
    .navigationBarTitleDisplayMode(.inline)
    .refreshable { await viewModel.load(force: true) }
    .task { await viewModel.load() }
  }

  private var content: some View {
    ScrollView {
      VStack(spacing: 20) {
        GlassCard(backgroundColor: pnlTint(totalUnrealizedPnl)) {
          VStack(alignment: .leading, spacing: 12) {
            Text("Total unrealized P/L")
              .typography(.small, weight: .semibold)
              .foregroundStyle(.secondary)

            Text(signedCurrency(totalUnrealizedPnl))
              .typography(.displayNumber)
              .foregroundStyle(pnlColor(totalUnrealizedPnl))
              .contentTransition(.numericText(value: totalUnrealizedPnl))
              .appAnimation(AppMotion.state, value: totalUnrealizedPnl)

            if let response = viewModel.response {
              Text(
                "\(response.sectors.count) sectors · \(response.totalMarketValue.currency) market value"
              )
              .typography(.nano)
              .foregroundStyle(.secondary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        GlassCard {
          VStack(spacing: 20) {
            SectorGainsBarChart(sectors: sectors, colorScheme: colorScheme)
              .frame(minHeight: 220)

            VStack(alignment: .leading, spacing: 12) {
              ForEach(sectors) { sector in
                sectorRow(sector)
              }
            }
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
  }

  private func sectorRow(_ sector: SectorGainItem) -> some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(sector.sector)
          .typography(.label, weight: .semibold)
        Text("\(sector.weightPercent.formatted(.number.precision(.fractionLength(1))))% of portfolio")
          .typography(.nano)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      VStack(alignment: .trailing, spacing: 4) {
        Text(signedCurrency(sector.unrealizedPnl))
          .typography(.numeric, weight: .semibold)
          .foregroundStyle(pnlColor(sector.unrealizedPnl))
        Text("\(signedPercent(sector.unrealizedPnlPercent)) on cost")
          .typography(.numericSmall)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func signedCurrency(_ value: Double) -> String {
    if value > 0 { return "+\(value.currency)" }
    if value < 0 { return "-\((-value).currency)" }
    return value.currency
  }

  private func signedPercent(_ value: Double) -> String {
    let formatted = value.formatted(.number.precision(.fractionLength(1)))
    if value > 0 { return "+\(formatted)%" }
    if value < 0 { return "\(formatted)%" }
    return "\(formatted)%"
  }

  private func pnlColor(_ value: Double) -> Color {
    if value > 0 { return .green }
    if value < 0 { return .red }
    return .secondary
  }

  private func pnlTint(_ value: Double) -> Color {
    if value > 0 { return .green.opacity(0.12) }
    if value < 0 { return .red.opacity(0.12) }
    return .gray.opacity(0.12)
  }
}

private struct SectorGainsBarChart: View {
  let sectors: [SectorGainItem]
  let colorScheme: ColorScheme

  @State private var animationProgress: Double = 0

  var body: some View {
    Chart(sectors) { sector in
      BarMark(
        x: .value("Sector", sector.sector),
        y: .value("P/L", sector.unrealizedPnl * animationProgress)
      )
      .foregroundStyle(by: .value("Sector", sector.sector))
    }
    .chartForegroundStyleScale(
      domain: sectors.map(\.sector),
      range: sectors.indices.map { AllocationPalette.color(at: $0, colorScheme: colorScheme) }
    )
    .chartLegend(.hidden)
    .chartYAxis {
      AxisMarks(position: .leading)
    }
    .onAppear {
      withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.15)) {
        animationProgress = 1
      }
    }
  }
}

private enum AllocationPalette {
  static func color(at index: Int, colorScheme: ColorScheme) -> Color {
    let palette: [Color] = [
      AppTheme.Colors.tint(for: colorScheme),
      AppTheme.Colors.secondaryTint(for: colorScheme),
      .indigo,
      .orange,
      .pink,
      .mint,
      .cyan,
      .purple
    ]
    return palette[index % palette.count]
  }
}

private struct SectorGainsSkeletonView: View {
  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(.gray.opacity(0.12))
          .frame(minHeight: 110)
          .shimmer()

        GlassCard {
          VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(.gray.opacity(0.12))
              .frame(minHeight: 220)
              .shimmer()

            ForEach(0..<4, id: \.self) { _ in
              RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.gray.opacity(0.12))
                .frame(height: 44)
                .shimmer()
            }
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
  }
}

#if DEBUG
#Preview {
  NavigationStack {
    SectorGainsScreen()
  }
}
#endif
