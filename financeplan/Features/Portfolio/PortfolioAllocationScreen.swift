import Charts
import CoreTransferable
import ImageIO
import StockPlanShared
import SwiftUI
import UniformTypeIdentifiers
import SwiftData

@MainActor
struct PortfolioAllocationScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.displayScale) private var displayScale
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var viewModel: PortfolioViewModel

  @Query private var stocks: [SDPortfolioStock]

  @State private var sharePayload: SharePayload?
  @State private var isShareRendering = false

  private var totalValue: Double {
    stocks.reduce(0) { $0 + ($1.shares * $1.buyPrice) }
  }

  /// Cost-basis weights by position value, largest first.
  private var allocationSlices: [PortfolioAllocationSlice] {
    let total = totalValue
    guard total > 0 else { return [] }
    return stocks
      .map { stock in
        let value = stock.shares * stock.buyPrice
        return PortfolioAllocationSlice(
          id: stock.id,
          symbol: stock.symbol,
          value: value,
          percentage: (value / total) * 100
        )
      }
      .sorted { $0.value > $1.value }
  }

  var body: some View {
    Group {
      if viewModel.isLoading && stocks.isEmpty {
        PortfolioAllocationSkeletonView()
          .transition(.opacity)
      } else if let error = viewModel.errorMessage, stocks.isEmpty {
        ContentUnavailableView {
          Label("Unable to Load Portfolio", systemImage: "exclamationmark.triangle")
        } description: {
          Text(error)
        } actions: {
          Button("Retry") {
            Task { await viewModel.load(force: true) }
          }
          .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        allocationContent
          .transition(.opacity)
      }
    }
    .animation(.smooth(duration: 0.3), value: viewModel.isLoading)
    .onAppear {
        viewModel.setModelContext(modelContext)
    }
    .refreshable { await viewModel.load(force: true) }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        if !allocationSlices.isEmpty {
          Button {
            Task { await renderAndShare() }
          } label: {
            if isShareRendering {
              ProgressView()
            } else {
              Image(systemName: "square.and.arrow.up")
            }
          }
          .disabled(isShareRendering)
          .accessibilityLabel("Share allocation chart")
        }
      }
    }
    .sheet(item: $sharePayload) { payload in
      AllocationShareReadySheet(pngData: payload.pngData) {
        sharePayload = nil
      }
    }
  }

  @ViewBuilder
  private var allocationContent: some View {
    if allocationSlices.isEmpty {
      ContentUnavailableView {
        Label("No Allocation Yet", systemImage: "chart.pie.fill")
      } description: {
        Text("Add holdings under Holdings to see how your portfolio is split by cost basis.")
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollView {
        VStack(spacing: 20) {
            GlassCard(backgroundColor: .blue.opacity(0.12)) {
            VStack(alignment: .leading, spacing: 12) {
              Text("By cost basis")
                .typography(.small, weight: .semibold)
                .foregroundStyle(.secondary)

              Text(totalValue.currency)
                .typography(.hero, weight: .bold)
                .contentTransition(.numericText())

              Text(
                "\(allocationSlices.count) positions · percentages sum to how much each holding contributes to total value."
              )
              .typography(.nano)
              .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }

          GlassCard {
            VStack(spacing: 20) {
              AllocationDonutChart(
                slices: allocationSlices,
                colorScheme: colorScheme
              )
              .frame(height: 280)

              VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(allocationSlices.enumerated()), id: \.element.id) {
                  index, slice in
                  HStack(spacing: 12) {
                    Circle()
                      .fill(AllocationPalette.color(at: index, colorScheme: colorScheme))
                      .frame(width: 10, height: 10)

                    Text(slice.symbol)
                      .typography(.label, weight: .semibold)
                      .frame(maxWidth: .infinity, alignment: .leading)

                    Text(slice.percentage.formatted(.number.precision(.fractionLength(1))) + "%")
                      .typography(.label, weight: .semibold)
                      .foregroundStyle(.secondary)
                      .monospacedDigit()
                      .contentTransition(.numericText())

                    Text(slice.value.currency)
                      .typography(.small)
                      .foregroundStyle(.secondary)
                      .contentTransition(.numericText())
                  }
                }
              }
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
      }
    }
  }

  private func renderAndShare() async {
    guard !allocationSlices.isEmpty else { return }
    isShareRendering = true
    defer { isShareRendering = false }

    let card = PortfolioAllocationShareCard(
      slices: allocationSlices,
      totalValue: totalValue,
      colorScheme: colorScheme
    )

    let renderer = ImageRenderer(content: card)
    renderer.scale = displayScale

    guard let cgImage = renderer.cgImage,
      let data = Self.pngData(from: cgImage)
    else { return }
    sharePayload = SharePayload(pngData: data)
  }

  private static func pngData(from cgImage: CGImage) -> Data? {
    let data = NSMutableData()
    guard
      let dest = CGImageDestinationCreateWithData(
        data,
        UTType.png.identifier as CFString,
        1,
        nil
      )
    else { return nil }
    CGImageDestinationAddImage(dest, cgImage, nil)
    guard CGImageDestinationFinalize(dest) else { return nil }
    return data as Data
  }
}

// MARK: - Chart

private struct AllocationDonutChart: View {
  let slices: [PortfolioAllocationSlice]
  let colorScheme: ColorScheme

  @State private var animationProgress: Double = 0.0

  var body: some View {
    Chart(slices) { slice in
      SectorMark(
        angle: .value("Value", slice.value * animationProgress),
        innerRadius: .ratio(0.56),
        angularInset: 1.2
      )
      .cornerRadius(3)
      .foregroundStyle(by: .value("Symbol", slice.symbol))
    }
    .chartForegroundStyleScale(
      domain: slices.map(\.symbol),
      range: slices.indices.map { AllocationPalette.color(at: $0, colorScheme: colorScheme) }
    )
    .chartLegend(.hidden)
    .onAppear {
      withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
        animationProgress = 1.0
      }
    }
  }
}

private enum AllocationPalette {
  static func color(at index: Int, colorScheme: ColorScheme) -> Color {
    let palette: [Color] = [
      AppTheme.Colors.tint(for: colorScheme),
      AppTheme.Colors.secondaryTint(for: colorScheme),
      Color.indigo,
      Color.orange,
      Color.pink,
      Color.mint,
      Color.cyan,
      Color.purple
    ]
    return palette[index % palette.count]
  }
}

// MARK: - Share image card

private struct PortfolioAllocationShareCard: View {
  let slices: [PortfolioAllocationSlice]
  let totalValue: Double
  let colorScheme: ColorScheme

  var body: some View {
    VStack(spacing: 18) {
      VStack(spacing: 6) {
        Text("Portfolio allocation")
          .font(.title2.weight(.bold))
        Text(Date.now.formatted(date: .abbreviated, time: .omitted))
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      AllocationDonutChart(slices: slices, colorScheme: colorScheme)
        .frame(height: 240)

      Text(totalValue.currency)
        .font(.title3.weight(.semibold))

      Text("financeplan")
        .font(.caption)
        .foregroundStyle(.tertiary)

      Text("Percentages reflect cost basis weights; not investment advice.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(28)
    .frame(width: 360)
    .appGlassEffect(.rect(cornerRadius: 24))
  }
}

// MARK: - Share (SwiftUI only)

private struct SharePayload: Identifiable {
  let id = UUID()
  let pngData: Data
}

private struct PNGShareData: Transferable {
  let data: Data

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .png) { item in
      item.data
    }
  }
}

private struct AllocationShareReadySheet: View {
  let pngData: Data
  let onDismiss: () -> Void

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        Text("Your allocation chart is ready to share as an image.")
          .typography(.small)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.top, 8)

        ShareLink(
          item: PNGShareData(data: pngData),
          preview: SharePreview("Portfolio allocation", icon: Image(systemName: "chart.pie.fill"))
        ) {
          Label("Share image", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.borderedProminent)
      }
      .padding(24)
      .frame(maxWidth: .infinity)
      .navigationTitle("Share")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done", action: onDismiss)
        }
      }
    }
  }
}

// MARK: - Skeleton View

private struct PortfolioAllocationSkeletonView: View {
  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(.gray.opacity(0.12))
          .frame(height: 110)
          .shimmer()

        GlassCard {
          VStack(spacing: 20) {
            Circle()
              .stroke(.gray.opacity(0.12), lineWidth: 50)
              .frame(height: 200)
              .padding()
              .shimmer()

            VStack(alignment: .leading, spacing: 16) {
              ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .fill(.gray.opacity(0.12))
                  .frame(height: 20)
                  .shimmer()
              }
            }
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
  }
}
