import Charts
import ImageIO
import StockPlanShared
import SwiftUI
import UniformTypeIdentifiers
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct PortfolioAllocationScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.displayScale) private var displayScale
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var viewModel: PortfolioViewModel

  @Query private var stocks: [SDPortfolioStock]

  @State private var sharePayload: SharePayload?
  @State private var isShareRendering = false

  private var holdingsValue: Double {
    stocks.reduce(0) { $0 + ($1.shares * $1.buyPrice) }
  }

  private var cashBalance: Double {
    viewModel.cashBalance
  }

  private var totalValue: Double {
    holdingsValue + cashBalance
  }

  /// Cost-basis weights by position value, largest first.
  private var allocationSlices: [PortfolioAllocationSlice] {
    let total = totalValue
    guard total > 0 else { return [] }
    var slices = stocks
      .map { stock in
        let value = stock.shares * stock.buyPrice
        return PortfolioAllocationSlice(
          id: stock.id,
          symbol: stock.symbol,
          value: value,
          percentage: (value / total) * 100
        )
      }
    if cashBalance > 0 {
      slices.append(
        PortfolioAllocationSlice(
          id: "cash-position",
          symbol: "CASH",
          value: cashBalance,
          percentage: (cashBalance / total) * 100
        )
      )
    }
    return slices.sorted { $0.value > $1.value }
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
      AllocationShareReadySheet(
        pngData: payload.pngData,
        text: payload.text,
        slices: payload.slices,
        totalValue: payload.totalValue
      ) {
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
              .frame(minHeight: 280)

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
    let text = PortfolioAllocationShareFormatter.payload(
      slices: allocationSlices,
      totalValue: totalValue
    )
    sharePayload = SharePayload(
      pngData: data,
      text: text,
      slices: allocationSlices,
      totalValue: totalValue
    )
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
        .frame(minHeight: 240)

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
  let text: StockSharePayload
  let slices: [PortfolioAllocationSlice]
  let totalValue: Double
}

private struct AllocationShareReadySheet: View {
  let pngData: Data
  let text: StockSharePayload
  let slices: [PortfolioAllocationSlice]
  let totalValue: Double
  let onDismiss: () -> Void
  @State private var shareSheetItems: [Any] = []
  @State private var isShareSheetPresented = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        Text("Your allocation chart is ready to share as an image.")
          .typography(.small)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.top, 8)

        Button {
          openNativeShareSheet()
        } label: {
          Label("Share image and text", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.borderedProminent)

        StockChannelShareActions(
          payload: text,
          destinationPayload: { destination in
            PortfolioAllocationShareFormatter.payload(
              slices: slices,
              totalValue: totalValue,
              destination: destination
            )
          }
        )
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
    .sheet(isPresented: $isShareSheetPresented) {
      AllocationNativeShareSheet(items: shareSheetItems)
    }
  }

  private func openNativeShareSheet() {
    #if canImport(UIKit)
    if let image = UIImage(data: pngData) {
      shareSheetItems = [text.body, image]
    } else {
      shareSheetItems = [text.body]
    }
    #else
    shareSheetItems = [text.body]
    #endif
    isShareSheetPresented = true
  }
}

enum PortfolioAllocationShareFormatter {
  static func payload(
    slices: [PortfolioAllocationSlice],
    totalValue: Double?,
    destination: StockShareDestination? = nil,
    language: AppLanguage = .stored
  ) -> StockSharePayload {
    let limit = destination == .x ? 4 : 8
    let topSlices = slices.prefix(limit)
    var lines: [String] = []
    let title: String

    switch language {
    case .english:
      title = "Portfolio allocation"
      lines.append(title)
      if let totalValue {
        lines.append("Total value: \(totalValue.currency)")
      }
      lines.append(contentsOf: topSlices.map {
        "\($0.symbol): \($0.percentage.formatted(.number.precision(.fractionLength(1))))% (\($0.value.currency))"
      })
      if slices.count > limit {
        lines.append("+\(slices.count - limit) more positions")
      }
      lines.append("Not investment advice.")
    case .portuguesePortugal:
      title = "Alocação do portefólio"
      lines.append(title)
      if let totalValue {
        lines.append("Valor total: \(totalValue.currency)")
      }
      lines.append(contentsOf: topSlices.map {
        "\($0.symbol): \($0.percentage.formatted(.number.precision(.fractionLength(1))))% (\($0.value.currency))"
      })
      if slices.count > limit {
        lines.append("+\(slices.count - limit) posições")
      }
      lines.append("Não é aconselhamento financeiro.")
    }

    let body = lines.joined(separator: "\n")
    if destination == .x, body.count > 280 {
      return StockSharePayload(title: title, body: String(body.prefix(277)) + "...")
    }
    return StockSharePayload(title: title, body: body)
  }

}

#if canImport(UIKit)
private struct AllocationNativeShareSheet: UIViewControllerRepresentable {
  let items: [Any]

  func makeUIViewController(context _: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
#else
private struct AllocationNativeShareSheet: View {
  let items: [Any]

  var body: some View {
    Text(items.compactMap { $0 as? String }.joined(separator: "\n\n"))
      .padding()
  }
}
#endif

// MARK: - Skeleton View

private struct PortfolioAllocationSkeletonView: View {
  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(.gray.opacity(0.12))
          .frame(minHeight: 110)
          .shimmer()

        GlassCard {
          VStack(spacing: 20) {
            Circle()
              .stroke(.gray.opacity(0.12), lineWidth: 50)
              .frame(minHeight: 200)
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
