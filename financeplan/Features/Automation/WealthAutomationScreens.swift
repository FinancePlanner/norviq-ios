import Charts
import Combine
import Factory
import SwiftUI

@MainActor
private final class ForecastViewModel: ObservableObject {
  @Published var portfolios: [AutomationListOption] = []
  @Published var forecasts: [ForecastDefinitionWire] = []
  @Published var defaults: ForecastDefaultsWire?
  @Published var latestRun: ForecastRunWire?
  @Published var isLoading = false
  @Published var errorMessage: String?
  private let service: WealthAutomationServicing

  init(service: WealthAutomationServicing) {
    self.service = service
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      portfolios = try await service.portfolioLists()
      forecasts = try await service.forecasts()
      defaults = try await service.forecastDefaults()
      errorMessage = nil
    } catch { errorMessage = error.localizedDescription }
  }

  func save(
    portfolioID: String,
    name: String,
    horizon: Int,
    income: Double?,
    spending: Double?,
    includeCash: Bool,
    includeCrypto: Bool
  )
    async
  {
    do {
      let definition = try await service.createForecast(
        portfolioID: portfolioID,
        request: ForecastUpsertWire(
          name: name,
          baseCurrency: defaults?.baseCurrency ?? "EUR",
          horizonMonths: horizon,
          includeCash: includeCash,
          includeCrypto: includeCrypto,
          annualIncomeGrowth: 0.02,
          annualSpendingGrowth: 0.02,
          inflationAssumption: 0.02,
          monthlyIncomeOverride: income,
          monthlySpendingOverride: spending,
          targetAmount: nil,
          pathCount: 1_000
        )
      )
      forecasts.removeAll(where: { $0.portfolioListId == definition.portfolioListId })
      forecasts.append(definition)
      errorMessage = nil
    } catch { errorMessage = error.localizedDescription }
  }

  func run(_ forecast: ForecastDefinitionWire) async {
    isLoading = true
    defer { isLoading = false }
    do { latestRun = try await service.runForecast(id: forecast.id); errorMessage = nil }
    catch { errorMessage = error.localizedDescription }
  }
}

@MainActor
struct NetWorthForecastScreen: View {
  @StateObject private var model = ForecastViewModel(service: Container.shared.wealthAutomationService())
  @State private var selectedPortfolioID = ""
  @State private var name = "My forecast"
  @State private var horizon = 120
  @State private var income = ""
  @State private var spending = ""
  @State private var includeCash = true
  @State private var includeCrypto = false

  var body: some View {
    List {
      if let defaults = model.defaults {
        Section("Cash flow baseline") {
          LabeledContent("Income", value: defaults.monthlyIncome, format: .currency(code: defaults.baseCurrency))
          LabeledContent("Spending", value: defaults.monthlySpending, format: .currency(code: defaults.baseCurrency))
          LabeledContent("Net flow", value: defaults.monthlyNetFlow, format: .currency(code: defaults.baseCurrency))
          Text(defaults.cashFlowSource.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      Section("New forecast") {
        Picker("Portfolio", selection: $selectedPortfolioID) {
          Text("Choose").tag("")
          ForEach(model.portfolios) { Text($0.name).tag($0.id.uuidString) }
        }
        TextField("Name", text: $name)
        Stepper("\(horizon) months", value: $horizon, in: 12...600, step: 12)
        TextField("Monthly income override", text: $income).keyboardType(.decimalPad)
        TextField("Monthly spending override", text: $spending).keyboardType(.decimalPad)
        Toggle("Include cash", isOn: $includeCash)
        Toggle("Include crypto", isOn: $includeCrypto)
        Button("Save forecast", systemImage: "tray.and.arrow.down") {
          Task { await model.save(
            portfolioID: selectedPortfolioID,
            name: name,
            horizon: horizon,
            income: Double(income),
            spending: Double(spending),
            includeCash: includeCash,
            includeCrypto: includeCrypto
          ) }
        }
        .disabled(selectedPortfolioID.isEmpty || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      Section("Saved forecasts") {
        ForEach(model.forecasts) { forecast in
          VStack(alignment: .leading, spacing: 8) {
            Text(forecast.name).font(.headline)
            Text("\(forecast.horizonMonths) months · \(forecast.pathCount) paths").font(.caption).foregroundStyle(
              .secondary
            )
            Button("Run now", systemImage: "play.fill") { Task { await model.run(forecast) } }
              .buttonStyle(.borderedProminent)
          }.padding(.vertical, 4)
        }
      }
      if let run = model.latestRun {
        ForecastResultSection(run: run)
      }
      if let error = model.errorMessage {
        Section { Text(error).foregroundStyle(.red).accessibilityLabel(
          "Error: \(error)"
        ) } }
    }
    .navigationTitle("Net Worth Forecast")
    .overlay {
      if model.isLoading {
        ProgressView().controlSize(.large)
      }
    }
    .task {
      await model.load(); if selectedPortfolioID.isEmpty {
        selectedPortfolioID = model.portfolios.first?.id.uuidString ?? ""
      }
    }
    .refreshable { await model.load() }
  }
}

private struct ForecastResultSection: View {
  let run: ForecastRunWire
  var body: some View {
    Section("Latest projection") {
      if let probability = run.targetProbability {
        LabeledContent(
          "Target probability",
          value: probability,
          format: .percent.precision(.fractionLength(0))
        ) }
      Chart(run.timeline) { point in
        if let value = point.value(at: 10) {
          LineMark(x: .value("Month", point.month), y: .value("P10", value)).foregroundStyle(
            .secondary
          ) }
        if let value = point.value(at: 50) {
          LineMark(x: .value("Month", point.month), y: .value("Median", value)).foregroundStyle(
            .blue
          ).lineStyle(.init(lineWidth: 3)) }
        if let value = point.value(at: 90) {
          LineMark(x: .value("Month", point.month), y: .value("P90", value)).foregroundStyle(
            .green
          ) }
      }
      .frame(minHeight: 240)
      .accessibilityLabel("Forecast probability bands")
      LabeledContent("Starting value", value: run.startingValue, format: .currency(code: run.assumptions.baseCurrency))
    }
  }
}

@MainActor
private final class ScreensViewModel: ObservableObject {
  @Published var lists: [AutomationListOption] = []
  @Published var screens: [WatchlistScreenWire] = []
  @Published var catalog: [ScreenMetricWire] = []
  @Published var evaluation: ScreenEvaluationWire?
  @Published var errorMessage: String?
  private let service: WealthAutomationServicing
  init(service: WealthAutomationServicing) {
    self.service = service
  }

  func load() async {
    do { lists = try await service.watchlistLists(); screens = try await service.screens(); catalog = try await service.screenCatalog(
    ); errorMessage = nil } catch { errorMessage = error.localizedDescription }
  }

  func create(
    name: String,
    listID: String,
    metric: String,
    comparison: String,
    period: String,
    value: Double?,
    alerts: Bool
  )
    async
  {
    do {
      let condition = ScreenConditionWire(
        id: UUID().uuidString,
        metric: metric,
        comparison: comparison,
        period: period,
        value: comparison == "improving" || comparison == "deteriorating" ? nil : value
      )
      let screen = try await service.createScreen(
        .init(
          name: name,
          watchlistListIds: [listID],
          logicalOperator: "all",
          groups: [.init(id: UUID().uuidString, logicalOperator: "all", conditions: [condition])],
          alertsEnabled: alerts
        )
      )
      screens.append(screen); errorMessage = nil
    } catch { errorMessage = error.localizedDescription }
  }

  func evaluate(_ screen: WatchlistScreenWire) async {
    do { evaluation = try await service.evaluateScreen(id: screen.id); errorMessage = nil }
    catch { errorMessage = error.localizedDescription }
  }
}

@MainActor
struct SmartScreeningScreen: View {
  @StateObject private var model = ScreensViewModel(service: Container.shared.wealthAutomationService())
  @State private var name = "Improving fundamentals"
  @State private var listID = ""
  @State private var metric = "revenue_growth"
  @State private var comparison = "improving"
  @State private var period = "annual"
  @State private var threshold = ""
  @State private var alerts = true

  var body: some View {
    List {
      Section("New smart screen") {
        TextField("Name", text: $name)
        Picker("Watchlist", selection: $listID) { Text("Choose").tag(""); ForEach(model.lists) { Text($0.name).tag(
          $0.id.uuidString
        ) } }
        Picker("Metric", selection: $metric) { ForEach(model.catalog) { Text($0.label).tag($0.id) } }
        Picker("Period", selection: $period) { Text("TTM").tag("ttm"); Text("Annual").tag("annual"); Text("Quarterly").tag(
          "quarterly"
        ) }
        Picker("Comparison", selection: $comparison) { Text("Improving").tag("improving"); Text("Deteriorating").tag(
          "deteriorating"
        ); Text("Greater than").tag("greater_than"); Text("Less than").tag("less_than") }
        if comparison != "improving", comparison != "deteriorating" {
          TextField("Threshold", text: $threshold).keyboardType(
            .decimalPad
          ) }
        Toggle("Daily entry alerts", isOn: $alerts)
        Button("Create screen", systemImage: "line.3.horizontal.decrease.circle") { Task { await model.create(
          name: name,
          listID: listID,
          metric: metric,
          comparison: comparison,
          period: period,
          value: Double(threshold),
          alerts: alerts
        ) } }.disabled(name.isEmpty || listID.isEmpty || metric.isEmpty)
      }
      Section("Saved screens") {
        ForEach(model.screens) { screen in
          VStack(alignment: .leading, spacing: 8) { Text(screen.name).font(.headline); Text(
            screen.alertsEnabled ? "Entry alerts on" : "Alerts off"
          ).font(.caption).foregroundStyle(.secondary); Button("Evaluate now", systemImage: "checkmark.circle") { Task { await model.evaluate(
            screen
          ) } }.buttonStyle(.bordered) }.padding(.vertical, 4)
        }
      }
      if let result = model.evaluation {
        Section("\(result.matches.count) of \(result.symbolCount) match") { ForEach(result.matches) { match in HStack { Text(
          match.symbol
        ).font(.headline); Spacer(); if match.isNew {
          Text("New").font(.caption).foregroundStyle(.green)
        } } } }
      }
      if let error = model.errorMessage {
        Section { Text(error).foregroundStyle(.red) }
      }
    }
    .navigationTitle("Smart Screens")
    .task { await model.load(); listID = listID.isEmpty ? model.lists.first?.id.uuidString ?? "" : listID; metric = model.catalog.first?.id ?? metric }
    .refreshable { await model.load() }
  }
}

@MainActor
private final class RebalancingViewModel: ObservableObject {
  @Published var portfolios: [AutomationListOption] = []
  @Published var policy: RebalancingPolicyWire?
  @Published var preview: RebalancePreviewWire?
  @Published var errorMessage: String?
  private let service: WealthAutomationServicing
  init(service: WealthAutomationServicing) {
    self.service = service
  }

  func load() async {
    do { portfolios = try await service.portfolioLists(); errorMessage = nil } catch { errorMessage = error.localizedDescription }
  }

  func select(_ id: String) async {
    do
    { policy = try await service.rebalancingPolicy(portfolioID: id); preview = policy == nil ? nil : try await service.previewRebalancing(
      portfolioID: id
    ); errorMessage = nil } catch { errorMessage = error.localizedDescription } }

  func save(portfolioID: String, cadence: String, drift: Double, targets: String, enabled: Bool) async {
    do { let parsed = try Self.parseTargets(targets); policy = try await service.saveRebalancingPolicy(
      portfolioID: portfolioID,
      request: .init(enabled: enabled, cadence: cadence, driftThreshold: drift / 100, targets: parsed)
    ); preview = try await service.previewRebalancing(portfolioID: portfolioID); errorMessage = nil } catch { errorMessage = error.localizedDescription }
  }

  static func parseTargets(_ raw: String) throws -> [RebalanceTargetWire] {
    let targets = try raw.split(separator: ",").enumerated().map { index, part -> RebalanceTargetWire in
      let pair = part.split(separator: ":", maxSplits: 1).map(String.init)
      guard pair.count == 2, let weight = Double(pair[1]), weight > 0 else { throw ValidationError.invalidTargets }
      let asset = pair[0].trimmingCharacters(in: .whitespacesAndNewlines)
      return .init(
        id: UUID().uuidString,
        kind: asset.lowercased() == "cash" ? "cash" : "symbol",
        symbol: asset.lowercased() == "cash" ? nil : asset.uppercased(),
        targetWeight: weight / 100
      )
    }
    guard abs(targets.reduce(0) { $0 + $1.targetWeight } - 1) < 0.0001 else { throw ValidationError.invalidTargets }
    return targets
  }

  enum ValidationError: LocalizedError { case invalidTargets; var errorDescription: String? {
    "Enter targets like AAPL:60, MSFT:30, cash:10 and total 100%."
  } }
}

@MainActor
struct RebalancingRulesScreen: View {
  @StateObject private var model = RebalancingViewModel(service: Container.shared.wealthAutomationService())
  @State private var portfolioID = ""
  @State private var cadence = "quarterly"
  @State private var drift = 5.0
  @State private var targets = ""
  @State private var enabled = true
  var body: some View {
    List {
      Section("Rule") {
        Picker("Portfolio", selection: $portfolioID) { Text("Choose").tag(""); ForEach(model.portfolios) { Text($0.name).tag(
          $0.id.uuidString
        ) } }.onChange(of: portfolioID) { _, value in Task { await model.select(value) } }
        Picker("Cadence", selection: $cadence) { Text("Monthly").tag("monthly"); Text("Quarterly").tag("quarterly"); Text(
          "Semi-annual"
        ).tag("semi_annual"); Text("Annual").tag("annual"); Text("Drift only").tag("none") }
        LabeledContent("Drift threshold", value: drift / 100, format: .percent.precision(.fractionLength(1)))
        Slider(value: $drift, in: 0.5...25, step: 0.5)
        TextField("AAPL:60, MSFT:30, cash:10", text: $targets).textInputAutocapitalization(.characters)
        Toggle("Enabled", isOn: $enabled)
        Button("Save and preview", systemImage: "scale.3d") { Task { await model.save(
          portfolioID: portfolioID,
          cadence: cadence,
          drift: drift,
          targets: targets,
          enabled: enabled
        ) } }.disabled(portfolioID.isEmpty || targets.isEmpty)
      }
      if let preview = model.preview {
        Section("Review-only draft") {
          LabeledContent("Portfolio value", value: preview.portfolioValue, format: .currency(code: preview.currency))
          LabeledContent(
            "Maximum drift",
            value: preview.maximumDrift / 100,
            format: .percent.precision(.fractionLength(1))
          )
          ForEach(preview.trades) { trade in VStack(alignment: .leading) { Text(trade.symbol ?? "Cash").font(.headline); Text(
            "\(trade.action.capitalized) \(trade.amount.formatted(.currency(code: preview.currency))) · \(trade.currentWeight.formatted(.percent)) → \(trade.targetWeight.formatted(.percent))"
          ).font(.caption).foregroundStyle(.secondary) } }
          Text("Nothing is executed automatically. Confirm trades with your broker after review.").font(.footnote).foregroundStyle(
            .secondary
          )
        }
      }
      if let error = model.errorMessage {
        Section { Text(error).foregroundStyle(.red) }
      }
    }
    .navigationTitle("Rebalancing Rules")
    .task {
      await model.load(); portfolioID = model.portfolios.first?.id.uuidString ?? ""; if !portfolioID.isEmpty
      {
        await model.select(
          portfolioID
        ) }
    }
  }
}

@MainActor
private final class InboxViewModel: ObservableObject {
  @Published var page = NotificationPageWire(items: [], nextCursor: nil, unreadCount: 0)
  @Published var errorMessage: String?
  private let service: WealthAutomationServicing
  init(service: WealthAutomationServicing) {
    self.service = service
  }

  func load() async {
    do { page = try await service.notifications(); errorMessage = nil } catch { errorMessage = error.localizedDescription }
  }

  func read(_ item: NotificationItemWire) async {
    do { try await service.markNotificationRead(id: item.id); await load() } catch { errorMessage = error.localizedDescription }
  }

  func readAll() async {
    do { try await service.markAllNotificationsRead(); await load() } catch { errorMessage = error.localizedDescription }
  }
}

@MainActor
struct NotificationInboxScreen: View {
  @StateObject private var model = InboxViewModel(service: Container.shared.wealthAutomationService())
  var body: some View {
    List {
      if let error = model.errorMessage {
        Text(error).foregroundStyle(.red)
      }
      if model.page.items.isEmpty {
        ContentUnavailableView(
          "No notifications",
          systemImage: "bell",
          description: Text("Price, budget, earnings, tax, screen, and rebalance alerts appear here.")
        ) }
      ForEach(model.page.items) { item in Button { Task { await model.read(item) } } label: { VStack(
        alignment: .leading,
        spacing: 5
      ) { HStack { Text(item.kind.replacingOccurrences(of: "_", with: " ").uppercased()).font(.caption2).foregroundStyle(
        .secondary
      ); if item.readAt == nil {
        Circle().fill(.blue).frame(width: 7, height: 7).accessibilityLabel("Unread")
      } }; Text(
        item.title
      ).font(.headline).foregroundStyle(.primary); Text(item.body).font(.subheadline).foregroundStyle(.secondary) } }.buttonStyle(
        .plain
      ).accessibilityHint("Marks this notification as read") }
    }
    .navigationTitle("Notifications")
    .toolbar {
      if model.page.unreadCount > 0
      {
        ToolbarItem(placement: .topBarTrailing) { Button("Read all") { Task { await model.readAll(
        ) } } } }
    }
    .task { await model.load() }
    .refreshable { await model.load() }
  }
}
