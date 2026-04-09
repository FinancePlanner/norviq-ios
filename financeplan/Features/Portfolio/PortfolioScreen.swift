import Combine
import StockPlanShared
import SwiftUI
import SwiftData

@MainActor
struct PortfolioScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var viewModel: PortfolioViewModel

  @Query(sort: \SDPortfolioStock.symbol) private var stocks: [SDPortfolioStock]

  @State private var isAddPositionPresented = false
  @State private var destructiveFeedbackTrigger = 0
  @State private var selectedTimeRange: TimeRange = .month
  @State private var selectedAssetFilter: AssetFilter = .all
  @State private var chartData: [ChartDataPoint] = []

  enum TimeRange: String, CaseIterable, Identifiable {
      case day = "1D"
      case week = "1W"
      case month = "1M"
      case threeMonths = "3M"
      case year = "1Y"
      case all = "ALL"
      var id: String { rawValue }
  }

  enum AssetFilter: String, CaseIterable, Identifiable {
      case all = "All Assets"
      case stocks = "Stocks"
      case etfs = "ETFs"
      case crypto = "Crypto"
      var id: String { rawValue }
  }

  private var totalValue: Double {
    stocks.reduce(0) { $0 + ($1.shares * $1.buyPrice) }
  }

  private var filteredStocks: [SDPortfolioStock] {
      switch selectedAssetFilter {
      case .all: return stocks
      case .stocks: return stocks.filter { ($0.category ?? AssetCategory.stock.rawValue) == AssetCategory.stock.rawValue }
      case .etfs: return stocks.filter { ($0.category ?? AssetCategory.stock.rawValue) == AssetCategory.etf.rawValue }
      case .crypto: return stocks.filter { ($0.category ?? AssetCategory.stock.rawValue) == AssetCategory.crypto.rawValue }
      }
  }

  private var totalShares: Double {
    stocks.reduce(0) { $0 + $1.shares }
  }

  private var averagePositionValue: Double {
    guard !stocks.isEmpty else { return 0 }
    return totalValue / Double(stocks.count)
  }

  var body: some View {
    Group {
      if viewModel.isLoading && stocks.isEmpty {
        PortfolioSkeletonView()
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
        ScrollView {
          VStack(spacing: 16) {
            // Hero Chart Card
            GlassCard(cornerRadius: 22) {
              VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                  Text("Portfolio value")
                    .typography(.small, weight: .semibold)
                    .foregroundStyle(.secondary)

                  HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(totalValue.currency)
                      .typography(.hero, weight: .bold)
                      .contentTransition(.numericText())
                    Text("\(stocks.count) positions")
                      .typography(.small)
                      .foregroundStyle(.secondary)
                  }

                  HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                    Text("+2.31% ($2,816.32)")
                  }
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(.green)
                }
                .padding(.horizontal, 4)

                InteractiveLineChart(data: chartData, color: .green)
                  .frame(height: 160)
                  .padding(.horizontal, -12) // Bleed to edges of card padding

                // Time range picker
                HStack(spacing: 0) {
                  ForEach(TimeRange.allCases) { range in
                    Button(action: {
                      withAnimation { selectedTimeRange = range }
                    }) {
                      Text(range.rawValue)
                        .font(.caption.weight(.semibold))
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(selectedTimeRange == range ? Color.white.opacity(0.15) : Color.clear)
                        .cornerRadius(8)
                        .foregroundStyle(selectedTimeRange == range ? .primary : .secondary)
                    }
                  }
                }

                HStack {
                  PortfolioMetricPill(
                    title: "Shares",
                    value: totalShares.formatted(.number.precision(.fractionLength(0...2))),
                    tint: AppTheme.Colors.secondaryTint(for: colorScheme)
                  )
                  PortfolioMetricPill(
                    title: "Avg / position",
                    value: averagePositionValue.currency,
                    tint: AppTheme.Colors.tint(for: colorScheme)
                  )
                }
              }
            }
            .foregroundStyle(.primary)

            // Asset Filter
            HStack(spacing: 0) {
              ForEach(AssetFilter.allCases) { filter in
                Button(action: {
                  withAnimation { selectedAssetFilter = filter }
                }) {
                  Text(filter.rawValue)
                    .font(.subheadline.weight(.medium))
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(selectedAssetFilter == filter ? Color.white.opacity(0.15) : Color.clear)
                    .cornerRadius(10)
                    .foregroundStyle(selectedAssetFilter == filter ? .primary : .secondary)
                }
              }
            }
            .padding(4)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(14)

            if filteredStocks.isEmpty {
              ContentUnavailableView {
                Label("No Positions", systemImage: "chart.line.uptrend.xyaxis")
              } description: {
                Text("Add your first holding or change your filter.")
              } actions: {
                Button("Add Position") {
                  isAddPositionPresented = true
                }
                .buttonStyle(.borderedProminent)
              }
              .padding(.vertical, 24)
            } else {
              ForEach(filteredStocks) { stock in
                NavigationLink {
                  StockDetailScreen(stockId: stock.id, initialSymbol: stock.symbol)
                } label: {
                  PortfolioRow(stock: stock)
                }
                .buttonStyle(CardButtonStyle())
                .contextMenu {
                  Button("Edit", systemImage: "pencil") {
                    viewModel.beginEdit(StockResponse(
                        id: stock.id,
                        symbol: stock.symbol,
                        shares: stock.shares,
                        buyPrice: stock.buyPrice,
                        buyDate: stock.buyDate,
                        notes: stock.notes
                    ))
                  }

                  Button("Delete", systemImage: "trash", role: .destructive) {
                    destructiveFeedbackTrigger += 1
                    Task { await viewModel.delete(id: stock.id) }
                  }
                }
              }
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
        .transition(.opacity)
      }
    }
    .animation(.smooth(duration: 0.3), value: viewModel.isLoading)
    .onAppear {
        viewModel.setModelContext(modelContext)
        Task { await viewModel.load() }
        rebuildChartData()
    }
    .onChange(of: totalValue) { _, _ in
      rebuildChartData()
    }
    .onChange(of: selectedTimeRange) { _, _ in
      rebuildChartData()
    }
    .refreshable { await viewModel.load(force: true) }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          isAddPositionPresented = true
        } label: {
          Image(systemName: "plus")
        }
        .accessibilityLabel("Add position")
      }
    }
    .sheet(
      isPresented: Binding<Bool>(
        get: { viewModel.editingStock != nil },
        set: { if !$0 { viewModel.editingStock = nil } }
      )
    ) {
      if let stock = viewModel.editingStock {
        EditStockPositionSheet(
          stock: stock,
          isSaving: viewModel.isSaving,
          isDeleting: viewModel.isDeletingStock,
          onCancel: { viewModel.editingStock = nil },
          onSave: { updated in
            await viewModel.saveEdit(updated)
          },
          onDelete: {
            await viewModel.delete(id: stock.id)
          }
        )
      }
    }
    .sheet(isPresented: $isAddPositionPresented) {
      AddPositionSheet(
        title: "Add Position",
        draft: AddPositionDraft(
          symbol: "",
          companyName: nil,
          shares: "",
          buyPrice: "",
          buyDate: .now,
          notes: "",
          symbolLocked: false
        ),
        isSaving: viewModel.isSaving,
        onSave: { draft in
          await viewModel.saveNewPosition(draft)
        }
      )
    }
    .appSensoryFeedback(destructive: destructiveFeedbackTrigger)
  }

  private func rebuildChartData() {
    chartData = Self.makeChartData(totalValue: totalValue, timeRange: selectedTimeRange)
  }

  private static func makeChartData(totalValue: Double, timeRange: TimeRange) -> [ChartDataPoint] {
    let calendar = Calendar.current
    let today = Date()
    let baseValue = totalValue == 0 ? 100_000.0 : totalValue

    let (count, component): (Int, Calendar.Component) = {
      switch timeRange {
      case .day:
        return (24, .hour)
      case .week:
        return (7, .day)
      case .month:
        return (30, .day)
      case .threeMonths:
        return (90, .day)
      case .year:
        return (52, .weekOfYear)
      case .all:
        return (60, .month)
      }
    }()

    return (0..<count).compactMap { i in
      let offset = count - 1 - i
      guard let date = calendar.date(byAdding: component, value: -offset, to: today) else {
        return nil
      }

      let phase = Double(i)
      let seasonal = sin(phase * 0.45) * baseValue * 0.018
      let secondaryWave = cos(phase * 0.19) * baseValue * 0.007
      let trend = phase * (baseValue * 0.0012)
      let value = max(0, baseValue * 0.78 + seasonal + secondaryWave + trend)

      return ChartDataPoint(date: date, value: value)
    }
  }
}

private struct PortfolioRow: View {
  let stock: SDPortfolioStock

  var body: some View {
    GlassCard(cornerRadius: 22) {
      HStack(spacing: 16) {
        Circle()
          .fill(Color.white.opacity(0.1))
          .frame(width: 48, height: 48)
          .overlay(
            Text(stock.symbol.prefix(1))
              .font(.title2.weight(.bold))
              .foregroundStyle(.white)
          )

        VStack(alignment: .leading, spacing: 4) {
          Text(stock.symbol)
            .font(.headline)
            .foregroundStyle(.primary)

          if let notes = stock.notes, !notes.isEmpty {
            Text(notes)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          } else {
             Text("Holding")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Text("\(stock.shares.formatted(.number.precision(.fractionLength(0...2)))) Shares")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 4) {
          Text((stock.shares * stock.buyPrice).currency)
            .font(.headline)
            .foregroundStyle(.primary)

          // Hardcoded for presentation matching screenshot until live price is loaded
          Text("+1.20%")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.green)
        }
      }
      .padding(.vertical, 4)
    }
  }
}

private struct PortfolioMetricPill: View {
  let title: String
  let value: String
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .typography(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .typography(.small, weight: .semibold)
        .foregroundStyle(.primary)
        .contentTransition(.numericText())
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .appGlassEffect(.rect(cornerRadius: 16), tint: tint.opacity(0.10))
  }
}

// MARK: - Premium UI Helpers

private struct CardButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
      .opacity(configuration.isPressed ? 0.9 : 1.0)
  }
}

private struct PortfolioSkeletonView: View {
  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(.gray.opacity(0.12))
          .frame(height: 140)
          .shimmer()

        ForEach(0..<4, id: \.self) { _ in
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.gray.opacity(0.12))
            .frame(height: 110)
            .shimmer()
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
  }
}
