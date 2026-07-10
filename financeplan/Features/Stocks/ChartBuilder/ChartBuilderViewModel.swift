import Combine
import Factory
import Foundation
import StockPlanShared

@MainActor
final class ChartBuilderViewModel: ObservableObject {
  static let maxMetrics = 20
  static let maxCompareSymbols = 3

  let symbol: String
  let companyName: String?

  @Published private(set) var selectedMetricKeys: [String]
  @Published var period: ChartBuilderPeriodKind = .annual {
    didSet { periodDidChange() }
  }
  @Published var chartType: ChartBuilderChartType = .bar
  @Published var showsGrowthTable = true
  @Published private(set) var compareSymbols: [String] = []
  @Published private(set) var response: ChartBuilderResponse?
  @Published private(set) var isLoading = false
  @Published private(set) var isExporting = false
  @Published var errorMessage: String?
  @Published var exportItem: ChartBuilderExportItem?

  private let service: any MarketDataServicing
  private let exportDirectory: URL
  private var activeBuildID: UUID?
  private var activeExportID: UUID?

  init(
    symbol: String,
    companyName: String? = nil,
    service: any MarketDataServicing = Container.shared.marketDataService(),
    exportDirectory: URL = .temporaryDirectory
  ) {
    self.symbol = symbol.uppercased()
    self.companyName = companyName
    self.service = service
    self.exportDirectory = exportDirectory
    selectedMetricKeys = ["revenue", "freeCashFlow"]
  }

  var canBuild: Bool {
    !selectedMetricKeys.isEmpty && !isLoading
  }

  var selectedMetrics: [ChartMetricDescriptor] {
    selectedMetricKeys.compactMap { ChartBuilderMetricCatalog.byKey[$0] }
  }

  var chartTitle: String {
    let resolvedCompany = response?.companies.first(where: { $0.symbol == symbol })?.name
      ?? companyName
      ?? symbol
    let labels = response?.series
      .filter { $0.symbol == symbol }
      .map(\.label)
      .reduce(into: [String]()) { labels, label in
        if !labels.contains(label) { labels.append(label) }
      } ?? selectedMetrics.map(\.label)
    let metricTitle = labels.count == 1 ? labels[0] : "\(labels.count) Metrics"
    return "\(resolvedCompany) – \(metricTitle) (\(periodTitle))"
  }

  func isSelected(_ metric: ChartMetricDescriptor) -> Bool {
    selectedMetricKeys.contains(metric.key)
  }

  func isEnabled(_ metric: ChartMetricDescriptor) -> Bool {
    period != .ttm || metric.supportsTTM
  }

  func toggleMetric(_ metric: ChartMetricDescriptor) {
    guard isEnabled(metric) else { return }

    if let index = selectedMetricKeys.firstIndex(of: metric.key) {
      selectedMetricKeys.remove(at: index)
    } else {
      guard selectedMetricKeys.count < Self.maxMetrics else {
        errorMessage = "Choose up to \(Self.maxMetrics) metrics per chart."
        return
      }
      selectedMetricKeys.append(metric.key)
    }

    errorMessage = nil
    invalidateResult()
  }

  func addCompareSymbol(_ rawSymbol: String) {
    let normalized = rawSymbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard !normalized.isEmpty, normalized != symbol, !compareSymbols.contains(normalized) else { return }
    guard compareSymbols.count < Self.maxCompareSymbols else {
      errorMessage = "Compare up to \(Self.maxCompareSymbols) peer symbols."
      return
    }

    compareSymbols.append(normalized)
    errorMessage = nil
    invalidateResult()
  }

  func removeCompareSymbol(_ symbol: String) {
    compareSymbols.removeAll { $0 == symbol }
    invalidateResult()
  }

  func build() async {
    guard !selectedMetricKeys.isEmpty else {
      errorMessage = "Select at least one metric."
      return
    }

    let requestID = UUID()
    activeBuildID = requestID
    let requestMetrics = selectedMetricKeys
    let requestPeriod = period
    let requestCompare = compareSymbols
    isLoading = true
    errorMessage = nil
    defer {
      if activeBuildID == requestID {
        isLoading = false
        activeBuildID = nil
      }
    }

    do {
      let result = try await service.fetchChartBuilder(
        symbol: symbol,
        metrics: requestMetrics,
        period: requestPeriod,
        limit: Self.limit(for: requestPeriod),
        compare: requestCompare
      )
      try Task.checkCancellation()
      guard activeBuildID == requestID else { return }
      response = result
    } catch is CancellationError {
      return
    } catch {
      guard activeBuildID == requestID else { return }
      errorMessage = error.localizedDescription
    }
  }

  func exportCSV() async {
    guard !selectedMetricKeys.isEmpty else {
      errorMessage = "Select at least one metric."
      return
    }

    let requestID = UUID()
    activeExportID = requestID
    let requestMetrics = selectedMetricKeys
    let requestPeriod = period
    let requestCompare = compareSymbols
    isExporting = true
    errorMessage = nil
    defer {
      if activeExportID == requestID {
        isExporting = false
        activeExportID = nil
      }
    }

    do {
      let data = try await service.fetchChartBuilderCSV(
        symbol: symbol,
        metrics: requestMetrics,
        period: requestPeriod,
        limit: Self.limit(for: requestPeriod),
        compare: requestCompare
      )
      try Task.checkCancellation()
      guard activeExportID == requestID else { return }

      let url = exportDirectory.appending(
        path: "\(symbol)-chart-builder-\(requestPeriod.rawValue).csv",
        directoryHint: .notDirectory
      )
      try data.write(to: url, options: .atomic)
      exportItem = ChartBuilderExportItem(url: url)
    } catch is CancellationError {
      return
    } catch {
      guard activeExportID == requestID else { return }
      errorMessage = error.localizedDescription
    }
  }

  private var periodTitle: String {
    switch period {
    case .annual:
      "Annual"
    case .quarter:
      "Quarterly"
    case .ttm:
      "TTM"
    }
  }

  private func periodDidChange() {
    if period == .ttm {
      selectedMetricKeys.removeAll { key in
        ChartBuilderMetricCatalog.byKey[key]?.supportsTTM == false
      }
    }
    errorMessage = nil
    invalidateResult()
  }

  private func invalidateResult() {
    activeBuildID = nil
    activeExportID = nil
    response = nil
    exportItem = nil
    isLoading = false
    isExporting = false
  }

  private static func limit(for period: ChartBuilderPeriodKind) -> Int {
    period == .annual ? 10 : 20
  }
}
