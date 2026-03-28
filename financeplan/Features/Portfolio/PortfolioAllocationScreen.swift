import Charts
import CoreTransferable
import ImageIO
import StockPlanShared
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct PortfolioAllocationScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.displayScale) private var displayScale
  @EnvironmentObject private var viewModel: PortfolioViewModel
  @State private var sharePayload: SharePayload?
  @State private var isShareRendering = false

  var body: some View {
    Group {
      if viewModel.isLoading {
        ProgressView("Loading portfolio...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = viewModel.errorMessage {
        ContentUnavailableView {
          Label("Unable to Load Portfolio", systemImage: "exclamationmark.triangle")
        } description: {
          Text(error)
        } actions: {
          Button("Retry") {
            Task { await viewModel.load() }
          }
          .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        allocationContent
      }
    }
    .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
    .refreshable { await viewModel.load() }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        if !viewModel.allocationSlices.isEmpty {
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
    if viewModel.allocationSlices.isEmpty {
      ContentUnavailableView {
        Label("No Allocation Yet", systemImage: "chart.pie.fill")
      } description: {
        Text("Add holdings under Holdings to see how your portfolio is split by cost basis.")
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollView {
        VStack(spacing: 20) {
          GlassCard {
            VStack(alignment: .leading, spacing: 12) {
              Text("By cost basis")
                .typography(.small, weight: .semibold)
                .foregroundStyle(.secondary)

              Text(viewModel.totalValue.currency)
                .typography(.hero, weight: .bold)

              Text(
                "\(viewModel.allocationSlices.count) positions · percentages sum to how much each holding contributes to total value."
              )
              .typography(.nano)
              .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }

          GlassCard {
            VStack(spacing: 20) {
              AllocationDonutChart(
                slices: viewModel.allocationSlices,
                colorScheme: colorScheme
              )
              .frame(height: 280)

              VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(viewModel.allocationSlices.enumerated()), id: \.element.id) {
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

                    Text(slice.value.currency)
                      .typography(.small)
                      .foregroundStyle(.secondary)
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
    guard !viewModel.allocationSlices.isEmpty else { return }
    isShareRendering = true
    defer { isShareRendering = false }

    let card = PortfolioAllocationShareCard(
      slices: viewModel.allocationSlices,
      totalValue: viewModel.totalValue,
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

  var body: some View {
    Chart(slices) { slice in
      SectorMark(
        angle: .value("Value", slice.value),
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
      Color.purple,
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
    .background(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(AppTheme.Colors.cardBackground(for: colorScheme))
    )
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
