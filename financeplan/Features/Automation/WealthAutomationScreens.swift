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
    existingID: String?,
    portfolioID: String,
    name: String,
    baseCurrency: String,
    horizon: Int,
    pathCount: Int,
    income: Double?,
    spending: Double?,
    target: Double?,
    incomeGrowth: Double,
    spendingGrowth: Double,
    inflation: Double,
    includeCash: Bool,
    includeCrypto: Bool
  )
    async
  {
    do {
      let request = ForecastUpsertWire(
        name: name,
        baseCurrency: baseCurrency.uppercased(),
        horizonMonths: horizon,
        includeCash: includeCash,
        includeCrypto: includeCrypto,
        annualIncomeGrowth: incomeGrowth / 100,
        annualSpendingGrowth: spendingGrowth / 100,
        inflationAssumption: inflation / 100,
        monthlyIncomeOverride: income,
        monthlySpendingOverride: spending,
        targetAmount: target,
        pathCount: pathCount
      )
      let definition = if let existingID {
        try await service.updateForecast(id: existingID, request: request)
      } else {
        try await service.createForecast(portfolioID: portfolioID, request: request)
      }
      forecasts.removeAll(where: { $0.id == definition.id })
      forecasts.append(definition)
      forecasts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
      errorMessage = nil
    } catch { errorMessage = error.localizedDescription }
  }

  func delete(_ forecast: ForecastDefinitionWire) async {
    do {
      try await service.deleteForecast(id: forecast.id)
      forecasts.removeAll { $0.id == forecast.id }
      if latestRun?.forecastId == forecast.id {
        latestRun = nil
      }
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
  @State private var editingID: String?
  @State private var baseCurrency = "EUR"
  @State private var horizon = 120
  @State private var pathCount = 1_000
  @State private var income = ""
  @State private var spending = ""
  @State private var target = ""
  @State private var incomeGrowth = 2.0
  @State private var spendingGrowth = 2.0
  @State private var inflation = 2.0
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
      Section(editingID == nil ? "New forecast" : "Edit forecast") {
        Picker("Portfolio", selection: $selectedPortfolioID) {
          Text("Choose").tag("")
          ForEach(model.portfolios) { Text($0.name).tag($0.id.uuidString) }
        }
        TextField("Name", text: $name)
        TextField("Base currency", text: $baseCurrency).textInputAutocapitalization(.characters)
        Stepper("\(horizon) months", value: $horizon, in: 12...600, step: 12)
        Stepper("\(pathCount) simulation paths", value: $pathCount, in: 100...10_000, step: 100)
        TextField("Monthly income override", text: $income).keyboardType(.decimalPad)
        TextField("Monthly spending override", text: $spending).keyboardType(.decimalPad)
        TextField("Target amount", text: $target).keyboardType(.decimalPad)
        LabeledContent("Income growth", value: incomeGrowth / 100, format: .percent.precision(.fractionLength(1)))
        Slider(value: $incomeGrowth, in: -10...20, step: 0.5)
        LabeledContent("Spending growth", value: spendingGrowth / 100, format: .percent.precision(.fractionLength(1)))
        Slider(value: $spendingGrowth, in: -10...20, step: 0.5)
        LabeledContent("Inflation", value: inflation / 100, format: .percent.precision(.fractionLength(1)))
        Slider(value: $inflation, in: 0...20, step: 0.5)
        Toggle("Include cash", isOn: $includeCash)
        Toggle("Include crypto", isOn: $includeCrypto)
        Button(editingID == nil ? "Save forecast" : "Update forecast", systemImage: "tray.and.arrow.down") {
          Task { await model.save(
            existingID: editingID,
            portfolioID: selectedPortfolioID,
            name: name,
            baseCurrency: baseCurrency,
            horizon: horizon,
            pathCount: pathCount,
            income: Double(income),
            spending: Double(spending),
            target: Double(target),
            incomeGrowth: incomeGrowth,
            spendingGrowth: spendingGrowth,
            inflation: inflation,
            includeCash: includeCash,
            includeCrypto: includeCrypto
          ) }
        }
        .disabled(
          selectedPortfolioID.isEmpty || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || baseCurrency.count != 3
        )
        if editingID != nil {
          Button("Cancel editing", role: .cancel) { resetEditor() }
        }
      }
      Section("Saved forecasts") {
        ForEach(model.forecasts) { forecast in
          VStack(alignment: .leading, spacing: 8) {
            Text(forecast.name).font(.headline)
            Text("\(forecast.horizonMonths) months · \(forecast.pathCount) paths").font(.caption).foregroundStyle(
              .secondary
            )
            HStack { Button("Run now", systemImage: "play.fill") { Task { await model.run(forecast) } }.buttonStyle(
              .borderedProminent
            ); Button("Edit", systemImage: "pencil") { edit(forecast) }.buttonStyle(.bordered) }
          }.padding(.vertical, 4)
            .swipeActions { Button("Delete", role: .destructive) { Task { await model.delete(forecast) } } }
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
      if editingID == nil {
        baseCurrency = model.defaults?.baseCurrency ?? baseCurrency
      }
    }
    .refreshable { await model.load() }
  }

  private func edit(_ forecast: ForecastDefinitionWire) {
    editingID = forecast.id; selectedPortfolioID = forecast.portfolioListId; name = forecast.name; baseCurrency = forecast.baseCurrency
    horizon = forecast.horizonMonths; pathCount = forecast.pathCount; income = forecast.monthlyIncomeOverride.map { String(
      $0
    ) } ?? ""
    spending = forecast.monthlySpendingOverride.map { String($0) } ?? ""; target = forecast.targetAmount.map { String($0) } ?? ""
    incomeGrowth = forecast.annualIncomeGrowth * 100; spendingGrowth = forecast.annualSpendingGrowth * 100; inflation = forecast.inflationAssumption * 100
    includeCash = forecast.includeCash; includeCrypto = forecast.includeCrypto
  }

  private func resetEditor() {
    editingID = nil; name = "My forecast"; baseCurrency = model.defaults?.baseCurrency ?? "EUR"; horizon = 120; pathCount = 1_000
    income = ""; spending = ""; target = ""; incomeGrowth = 2; spendingGrowth = 2; inflation = 2; includeCash = true; includeCrypto = false
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

private struct ScreenConditionDraft: Identifiable {
  let id: UUID
  var metric: String
  var comparison: String
  var period: String
  var value: String

  init(
    id: UUID = UUID(),
    metric: String = "",
    comparison: String = "improving",
    period: String = "annual",
    value: String = ""
  ) {
    self.id = id; self.metric = metric; self.comparison = comparison; self.period = period; self.value = value
  }
}

private struct ScreenGroupDraft: Identifiable {
  let id: UUID
  var logicalOperator: String
  var conditions: [ScreenConditionDraft]

  init(id: UUID = UUID(), logicalOperator: String = "all", conditions: [ScreenConditionDraft] = [.init()]) {
    self.id = id; self.logicalOperator = logicalOperator; self.conditions = conditions
  }
}

@MainActor
private final class ScreensViewModel: ObservableObject {
  @Published var lists: [AutomationListOption] = []
  @Published var screens: [WatchlistScreenWire] = []
  @Published var catalog: [ScreenMetricWire] = []
  @Published var evaluation: ScreenEvaluationWire?
  @Published var history: [ScreenEvaluationWire] = []
  @Published var errorMessage: String?
  private let service: WealthAutomationServicing
  init(service: WealthAutomationServicing) {
    self.service = service
  }

  func load() async {
    do { lists = try await service.watchlistLists(); screens = try await service.screens(); catalog = try await service.screenCatalog(
    ); errorMessage = nil } catch { errorMessage = error.localizedDescription }
  }

  func save(
    existingID: String?,
    name: String,
    listIDs: Set<String>,
    logicalOperator: String,
    groups: [ScreenGroupDraft],
    alerts: Bool
  )
    async
  {
    do {
      let wireGroups = try groups.map { group in
        let conditions = try group.conditions.map { condition in
          guard !condition.metric.isEmpty else { throw ValidationError.missingMetric }
          let isTrend = condition.comparison == "improving" || condition.comparison == "deteriorating"
          let numericValue = isTrend ? nil : Double(condition.value)
          if !isTrend, numericValue == nil {
            throw ValidationError.missingThreshold
          }
          return ScreenConditionWire(
            id: condition.id.uuidString,
            metric: condition.metric,
            comparison: condition.comparison,
            period: condition.period,
            value: numericValue
          )
        }
        return ScreenGroupWire(id: group.id.uuidString, logicalOperator: group.logicalOperator, conditions: conditions)
      }
      let request = WatchlistScreenUpsertWire(
        name: name,
        watchlistListIds: listIDs.sorted(),
        logicalOperator: logicalOperator,
        groups: wireGroups,
        alertsEnabled: alerts
      )
      let screen = if let existingID {
        try await service.updateScreen(id: existingID, request: request)
      } else {
        try await service.createScreen(
          request
        ) }
      screens.removeAll { $0.id == screen.id }; screens.append(screen); screens.sort { $0.name < $1.name }; errorMessage = nil
    } catch { errorMessage = error.localizedDescription }
  }

  func evaluate(_ screen: WatchlistScreenWire) async {
    do { evaluation = try await service.evaluateScreen(id: screen.id); history = try await service.screenHistory(
      id: screen.id
    ); errorMessage = nil } catch { errorMessage = error.localizedDescription }
  }

  func loadHistory(_ screen: WatchlistScreenWire) async {
    do { history = try await service.screenHistory(id: screen.id); errorMessage = nil }
    catch { errorMessage = error.localizedDescription }
  }

  func delete(_ screen: WatchlistScreenWire) async {
    do { try await service.deleteScreen(id: screen.id); screens.removeAll { $0.id == screen.id }; history = []; errorMessage = nil }
    catch { errorMessage = error.localizedDescription }
  }

  enum ValidationError: LocalizedError {
    case missingMetric, missingThreshold
    var errorDescription: String? {
      switch self { case .missingMetric: "Every condition needs a metric."; case .missingThreshold: "Numeric comparisons need a threshold." }
    }
  }
}

@MainActor
struct SmartScreeningScreen: View {
  @StateObject private var model = ScreensViewModel(service: Container.shared.wealthAutomationService())
  private let initialScreenID: String?
  @State private var name = "Improving fundamentals"
  @State private var editingID: String?
  @State private var selectedListIDs: Set<String> = []
  @State private var logicalOperator = "all"
  @State private var groups: [ScreenGroupDraft] = [.init()]
  @State private var alerts = true

  init(initialScreenID: String? = nil) {
    self.initialScreenID = initialScreenID
  }

  var body: some View {
    List {
      Section(editingID == nil ? "New smart screen" : "Edit smart screen") {
        TextField("Name", text: $name)
        ForEach(model.lists) { list in Toggle(
          list.name,
          isOn: Binding(
            get: { selectedListIDs.contains(list.id.uuidString) },
            set: {
              selected in if selected {
                selectedListIDs.insert(list.id.uuidString)
              } else
              {
                selectedListIDs.remove(
                  list.id.uuidString
                ) }
            }
          )
        ) }
        Picker("Match groups", selection: $logicalOperator) { Text("All groups").tag("all"); Text("Any group").tag("any") }
        ForEach($groups) { $group in
          Section {
            Picker("Within group", selection: $group.logicalOperator) { Text("All conditions").tag("all"); Text(
              "Any condition"
            ).tag("any") }
            ForEach($group.conditions) { $condition in
              Picker("Metric", selection: $condition.metric) { Text("Choose").tag(""); ForEach(model.catalog) { Text(
                $0.label
              ).tag($0.id) } }
                .onChange(of: condition.metric) { _, metric in
                  condition.period = supportedPeriods(metric).first ?? "annual"
                  condition.comparison = supportedComparisons(metric).first ?? "greater_than"
                }
              Picker("Period", selection: $condition.period) { ForEach(supportedPeriods(condition.metric), id: \.self) { Text(
                $0.uppercased()
              ).tag($0) } }
              Picker("Comparison", selection: $condition.comparison) { ForEach(
                supportedComparisons(condition.metric),
                id: \.self
              ) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized).tag($0) } }
              if condition.comparison != "improving", condition.comparison != "deteriorating" {
                TextField(
                  "Threshold",
                  text: $condition.value
                ).keyboardType(.decimalPad) }
            }
            .onDelete { group.conditions.remove(atOffsets: $0) }
            Button("Add condition", systemImage: "plus") { group.conditions.append(
              .init(metric: model.catalog.first?.id ?? "")
            ) }
          }
        }
        .onDelete { groups.remove(atOffsets: $0) }
        Button("Add group", systemImage: "plus.rectangle.on.rectangle") { groups.append(
          .init(conditions: [.init(metric: model.catalog.first?.id ?? "")])
        ) }
        Toggle("Daily entry alerts", isOn: $alerts)
        Button(editingID == nil ? "Create screen" : "Update screen", systemImage: "line.3.horizontal.decrease.circle") { Task { await model.save(
          existingID: editingID,
          name: name,
          listIDs: selectedListIDs,
          logicalOperator: logicalOperator,
          groups: groups,
          alerts: alerts
        ) } }.disabled(name.isEmpty || selectedListIDs.isEmpty || groups.isEmpty)
        if editingID != nil {
          Button("Cancel editing", role: .cancel) { resetScreenEditor() }
        }
      }
      Section("Saved screens") {
        ForEach(model.screens) { screen in
          VStack(alignment: .leading, spacing: 8) { Text(screen.name).font(.headline); Text(
            screen.alertsEnabled ? "Entry alerts on" : "Alerts off"
          ).font(.caption).foregroundStyle(.secondary); HStack { Button("Evaluate", systemImage: "checkmark.circle") { Task { await model.evaluate(
            screen
          ) } }.buttonStyle(.bordered); Button("Edit", systemImage: "pencil") { edit(screen) }.buttonStyle(.bordered); Button(
            "History",
            systemImage: "clock"
          ) { Task { await model.loadHistory(screen) } }.buttonStyle(.bordered) } }.padding(.vertical, 4)
            .swipeActions { Button("Delete", role: .destructive) { Task { await model.delete(screen) } } }
        }
      }
      if let result = model.evaluation {
        Section("\(result.matches.count) of \(result.symbolCount) match") { ForEach(result.matches) { match in HStack { Text(
          match.symbol
        ).font(.headline); Spacer(); if match.isNew {
          Text("New").font(.caption).foregroundStyle(.green)
        } } } }
      }
      if !model.history.isEmpty {
        Section("Evaluation history") { ForEach(model.history) { result in VStack(
          alignment: .leading
        ) { Text("\(result.matches.count) of \(result.symbolCount) matched").font(.headline); Text(result.evaluatedAt).font(
          .caption
        ).foregroundStyle(.secondary); Text(result.matches.map(\.symbol).joined(separator: ", ")).font(.caption) } } } }
      if let error = model.errorMessage {
        Section { Text(error).foregroundStyle(.red) }
      }
    }
    .navigationTitle("Smart Screens")
    .task {
      await model.load(); if selectedListIDs.isEmpty, let first = model.lists.first
      {
        selectedListIDs = [
          first.id.uuidString
        ] }; if groups.first?.conditions.first?.metric.isEmpty == true
      {
        groups[0].conditions[0].metric = model.catalog.first?.id ?? ""
      }; if
        let initialScreenID, let screen = model.screens.first(
          where: { $0.id == initialScreenID }
        )
      {
        await model.loadHistory(screen)
      }
    }
    .refreshable { await model.load() }
  }

  private func edit(_ screen: WatchlistScreenWire) {
    editingID = screen.id; name = screen.name; selectedListIDs = Set(screen.watchlistListIds); logicalOperator = screen.logicalOperator; alerts = screen.alertsEnabled
    groups = screen.groups.map { group in .init(
      logicalOperator: group.logicalOperator,
      conditions: group.conditions.map { .init(
        metric: $0.metric,
        comparison: $0.comparison,
        period: $0.period,
        value: $0.value.map { String($0) } ?? ""
      ) }
    ) }
  }

  private func resetScreenEditor() {
    editingID = nil; name = "Improving fundamentals"; logicalOperator = "all"; alerts = true; groups = [
      .init(conditions: [.init(metric: model.catalog.first?.id ?? "")])
    ]
  }

  private func supportedPeriods(_ metric: String) -> [String] {
    model.catalog.first(where: { $0.id == metric })?.supportedPeriods ?? ["annual"]
  }

  private func supportedComparisons(_ metric: String) -> [String] {
    model.catalog.first(where: { $0.id == metric })?.supportedComparisons ?? ["greater_than", "less_than"]
  }
}

@MainActor
private final class RebalancingRulesViewModel: ObservableObject {
  @Published var portfolios: [AutomationListOption] = []
  @Published var policy: RebalancingPolicyWire?
  @Published var preview: RebalancePreviewWire?
  @Published var events: [RebalanceEventWire] = []
  @Published var errorMessage: String?
  private let service: WealthAutomationServicing
  init(service: WealthAutomationServicing) {
    self.service = service
  }

  func load() async {
    do { portfolios = try await service.portfolioLists(); errorMessage = nil } catch { errorMessage = error.localizedDescription }
  }

  func select(_ id: String) async {
    do {
      async let loadedPolicy = service.rebalancingPolicy(portfolioID: id)
      async let loadedEvents = service.rebalanceEvents(portfolioID: id)
      policy = try await loadedPolicy; events = try await loadedEvents
      preview = policy == nil ? nil : try await service.previewRebalancing(portfolioID: id)
      errorMessage = nil
    } catch { errorMessage = error.localizedDescription }
  }

  func save(portfolioID: String, baseCurrency: String, cadence: String, drift: Double, targets: String, enabled: Bool) async {
    do { let parsed = try RebalanceTargetsParser.parse(targets); policy = try await service.saveRebalancingPolicy(
      portfolioID: portfolioID,
      request: .init(
        enabled: enabled,
        baseCurrency: baseCurrency.uppercased(),
        cadence: cadence,
        driftThreshold: drift / 100,
        targets: parsed
      )
    ); preview = try await service.previewRebalancing(portfolioID: portfolioID); errorMessage = nil } catch { errorMessage = error.localizedDescription }
  }

  func updateEvent(portfolioID: String, event: RebalanceEventWire, confirm: Bool) async {
    do {
      let updated = if confirm {
        try await service.confirmRebalanceEvent(portfolioID: portfolioID, eventID: event.id)
      } else {
        try await service.dismissRebalanceEvent(
          portfolioID: portfolioID,
          eventID: event.id
        ) }
      events = events.map { $0.id == updated.id ? updated : $0 }; policy = try await service.rebalancingPolicy(
        portfolioID: portfolioID
      ); errorMessage = nil
    } catch { errorMessage = error.localizedDescription }
  }

}

@MainActor
struct RebalancingRulesScreen: View {
  @StateObject private var model = RebalancingRulesViewModel(service: Container.shared.wealthAutomationService())
  private let initialPortfolioID: String?
  @State private var portfolioID = ""
  @State private var baseCurrency = "EUR"
  @State private var cadence = "quarterly"
  @State private var drift = 5.0
  @State private var targets = ""
  @State private var enabled = true

  init(initialPortfolioID: String? = nil) {
    self.initialPortfolioID = initialPortfolioID
  }

  var body: some View {
    List {
      Section("Rule") {
        Picker("Portfolio", selection: $portfolioID) { Text("Choose").tag(""); ForEach(model.portfolios) { Text($0.name).tag(
          $0.id.uuidString
        ) } }.onChange(of: portfolioID) { _, value in Task { await loadPortfolio(value) } }
        TextField("Base currency", text: $baseCurrency).textInputAutocapitalization(.characters)
        Picker("Cadence", selection: $cadence) { Text("Monthly").tag("monthly"); Text("Quarterly").tag("quarterly"); Text(
          "Semi-annual"
        ).tag("semiannual"); Text("Annual").tag("annual"); Text("Drift only").tag("disabled") }
        LabeledContent("Drift threshold", value: drift / 100, format: .percent.precision(.fractionLength(1)))
        Slider(value: $drift, in: 0.5...25, step: 0.5)
        TextField("AAPL:60, MSFT:30, cash:10", text: $targets).textInputAutocapitalization(.characters)
        Toggle("Enabled", isOn: $enabled)
        Button("Save and preview", systemImage: "scale.3d") { Task { await model.save(
          portfolioID: portfolioID,
          baseCurrency: baseCurrency,
          cadence: cadence,
          drift: drift,
          targets: targets,
          enabled: enabled
        ) } }.disabled(portfolioID.isEmpty || targets.isEmpty || baseCurrency.count != 3)
      }
      if let preview = model.preview {
        Section("Review-only draft") {
          LabeledContent("Portfolio value", value: preview.portfolioValue, format: .currency(code: preview.currency))
          LabeledContent(
            "Maximum drift",
            value: preview.maximumDrift,
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
      if !model.events.isEmpty {
        Section("Rebalance events") { ForEach(model.events) { event in VStack(
          alignment: .leading,
          spacing: 8
        ) { Text(event.status.capitalized).font(.headline); Text(
          "\(event.preview.maximumDrift.formatted(.percent)) max drift · \(event.preview.portfolioValue.formatted(.currency(code: event.preview.currency)))"
        ).font(.caption).foregroundStyle(.secondary); if event.status == "pending" {
          HStack { Button("Confirm reviewed") { Task { await model.updateEvent(
            portfolioID: portfolioID,
            event: event,
            confirm: true
          ) } }.buttonStyle(.borderedProminent); Button("Dismiss") { Task { await model.updateEvent(
            portfolioID: portfolioID,
            event: event,
            confirm: false
          ) } }.buttonStyle(.bordered) } } } } } }
      if let error = model.errorMessage {
        Section { Text(error).foregroundStyle(.red) }
      }
    }
    .navigationTitle("Rebalancing Rules")
    .task {
      await model.load(); portfolioID = initialPortfolioID ?? model.portfolios.first?.id.uuidString ?? ""; if !portfolioID.isEmpty
      {
        await loadPortfolio(portfolioID) }
    }
  }

  private func loadPortfolio(_ id: String) async {
    guard !id.isEmpty else { return }
    await model.select(id)
    if let policy = model.policy {
      baseCurrency = policy.baseCurrency; cadence = policy.cadence; drift = (policy.driftThreshold ?? 0.05) * 100; enabled = policy.enabled
      targets = policy.targets.map { "\($0.symbol ?? "cash"):\(($0.targetWeight * 100).formatted(.number.precision(.fractionLength(0...2))))" }.joined(
        separator: ", "
      )
    } else {
      baseCurrency = "EUR"; cadence = "quarterly"; drift = 5; targets = ""; enabled = true
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

  func load(reset: Bool = true) async {
    do {
      let loaded = try await service.notifications(cursor: reset ? nil : page.nextCursor)
      page = reset ? loaded : NotificationPageWire(
        items: page.items + loaded.items,
        nextCursor: loaded.nextCursor,
        unreadCount: loaded.unreadCount
      )
      errorMessage = nil
    } catch { errorMessage = error.localizedDescription }
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
      ForEach(model.page.items) { item in NavigationLink { notificationDestination(item) } label: { VStack(
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
      ).simultaneousGesture(TapGesture().onEnded { Task { await model.read(item) } }).accessibilityHint(
        "Opens this notification and marks it as read"
      ) }
      if model.page.nextCursor != nil {
        Button("Load older notifications", systemImage: "arrow.down.circle") { Task { await model.load(
          reset: false
        ) } } }
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

  @ViewBuilder
  private func notificationDestination(_ item: NotificationItemWire) -> some View {
    switch item.kind {
    case "watchlist_screen": SmartScreeningScreen(initialScreenID: item.payload["screen_id"])
    case "rebalancing": RebalancingRulesScreen(initialPortfolioID: item.payload["portfolio_list_id"])
    default: NotificationDetailScreen(item: item)
    }
  }
}

private struct NotificationDetailScreen: View {
  let item: NotificationItemWire
  var body: some View {
    List { Section { Text(item.body) } header: { Text(
      item.kind.replacingOccurrences(of: "_", with: " ").capitalized
    ) }; if let symbol = item.payload["symbol"] {
      Section("Symbol") { Text(symbol) }
    } }.navigationTitle(item.title).navigationBarTitleDisplayMode(
      .inline
    ) }
}
