import Factory
import Foundation
import Observation
import StockPlanShared

@MainActor
@Observable
final class MacroViewModel {
  var snapshot: InflationSnapshotResponse?
  var focusedTopMovers: [TopMoverDTO] = []
  var series: MacroSeriesResponse?
  var fedWatch: FedWatchResponse?
  var items: [MacroItemDTO] = []
  var news: [StockNews] = []
  var isLoading = false
  var errorMessage: String?

  /// Months of history shown in the trend chart.
  static let chartMonths = 36

  private let macroService: any MacroServicing
  private let marketDataService: any MarketDataServicing

  init(
    macroService: any MacroServicing = Container.shared.macroService(),
    marketDataService: any MarketDataServicing = Container.shared.marketDataService()
  ) {
    self.macroService = macroService
    self.marketDataService = marketDataService
  }

  /// Loads everything for a country. The snapshot is the only required call;
  /// chart/fed-watch/items are enrichments and fail silently to nil/empty.
  func load(country: String) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    async let snapshotTask = macroService.getCurrentInflation(country: country)
    async let moversTask = fetchMovers(country: country)
    async let seriesTask = fetchSeries(country: country)
    async let itemsTask = fetchItems(country: country)
    async let fedWatchTask = fetchFedWatch(country: country)
    async let newsTask = fetchNews()

    do {
      snapshot = try await snapshotTask
    } catch {
      errorMessage = error.localizedDescription
    }
    focusedTopMovers = await moversTask
    series = await seriesTask
    items = await itemsTask
    fedWatch = await fedWatchTask
    news = await newsTask
  }

  private func fetchNews() async -> [StockNews] {
    (try? await marketDataService.fetchMarketNews(limit: 6)) ?? []
  }

  private func fetchMovers(country: String) async -> [TopMoverDTO] {
    (try? await macroService.getTopMovers(country: country, focus: "utilities,food,shelter")) ?? []
  }

  private func fetchSeries(country: String) async -> MacroSeriesResponse? {
    try? await macroService.getSeries(country: country, series: "headline_cpi", limit: Self.chartMonths)
  }

  private func fetchItems(country: String) async -> [MacroItemDTO] {
    (try? await macroService.getItems(country: country))?.items ?? []
  }

  private func fetchFedWatch(country: String) async -> FedWatchResponse? {
    guard country == "US" else { return nil }
    return try? await macroService.getFedWatch()
  }

  var topMovers: [TopMoverDTO] {
    focusedTopMovers.isEmpty ? (snapshot?.topMovers ?? []) : focusedTopMovers
  }

  /// Chart points mapped for MetricTrendChart ("Jan 25"-style labels,
  /// first-seen order preserved by the ascending series response).
  var chartPoints: [MetricSeriesPoint] {
    guard let series else { return [] }
    return series.points.map {
      MetricSeriesPoint(label: Self.chartLabel(for: $0.date), value: $0.value)
    }
  }

  var chartSeriesName: String? {
    guard let series, !series.points.isEmpty else { return nil }
    return series.series
  }

  private static let periodParser: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()

  private static let labelFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM yy"
    return formatter
  }()

  static func chartLabel(for periodDate: String) -> String {
    guard let date = periodParser.date(from: periodDate) else { return periodDate }
    return labelFormatter.string(from: date)
  }
}
