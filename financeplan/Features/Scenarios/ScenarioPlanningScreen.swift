import Charts
import Factory
import Observation
import SwiftUI

// MARK: - View Model

@MainActor @Observable final class ScenarioPlanningViewModel {
  var catalog: ScenarioCatalogPayload?
  var runs: [ScenarioRunSummary] = []
  var scenarios: [ScenarioDefinitionSummary] = []
  var portfolios: [ScenarioPortfolio] = []
  var goals: [ScenarioGoal] = []
  var holdings: [ScenarioHolding] = []
  var cryptoHoldings: [ScenarioCryptoHolding] = []
  var riskProfiles: [ScenarioRiskProfile] = []
  var isLoading = false
  var isSubmitting = false
  var errorMessage: String?
  var snapshotPreview: ScenarioSnapshotPreview?
  private var pendingRequest: ScenarioRunRequest?
  private var pendingSavedScenario: (id: UUID, seed: Int64?)?

  private let service: ScenarioPlanningServiceProtocol

  init(service: ScenarioPlanningServiceProtocol) {
    self.service = service
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      async let c = service.catalog()
      async let r = service.runs()
      async let s = service.scenarios()
      async let p = service.portfolios()
      async let g = service.goals()
      async let rp = service.riskProfiles()
      async let ch = service.cryptoHoldings()
      catalog = try await c
      runs = try await r
      scenarios = try await s
      portfolios = try await p
      goals = try await g
      riskProfiles = try await rp
      cryptoHoldings = try await ch
      holdings = try await service.holdings(portfolioIDs: portfolios.map(\.id))
    } catch {
      errorMessage = "Scenario planning is temporarily unavailable."
    }
  }

  func capture(_ request: ScenarioRunRequest, baseCurrency: String, cryptoHoldingIDs: [UUID]) async {
    isSubmitting = true
    defer { isSubmitting = false }
    let currency = baseCurrency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard currency.count == 3 else {
      errorMessage = "Enter a valid three-letter snapshot currency."
      return
    }
    do {
      snapshotPreview = try await service.captureSnapshot(
        portfolioID: request.portfolioID,
        baseCurrency: currency,
        cryptoHoldingIDs: cryptoHoldingIDs
      )
      pendingRequest = request
      pendingSavedScenario = nil
    } catch {
      errorMessage = "The portfolio snapshot could not be captured."
    }
  }

  func capture(_ scenario: ScenarioDefinitionSummary, seed: Int64?, baseCurrency: String, cryptoHoldingIDs: [UUID]) async {
    isSubmitting = true
    defer { isSubmitting = false }
    let currency = baseCurrency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard currency.count == 3 else {
      errorMessage = "Enter a valid three-letter snapshot currency."
      return
    }
    do {
      snapshotPreview = try await service.captureSnapshot(
        portfolioID: scenario.portfolioListId,
        baseCurrency: currency,
        cryptoHoldingIDs: cryptoHoldingIDs
      )
      pendingSavedScenario = (scenario.id, seed)
      pendingRequest = nil
    } catch { errorMessage = "The portfolio snapshot could not be captured." }
  }

  func runReviewedSnapshot() async {
    guard let snapshot = snapshotPreview else { return }
    isSubmitting = true
    defer { isSubmitting = false }
    do {
      if let saved = pendingSavedScenario {
        runs.insert(try await service.createRun(scenarioID: saved.id, snapshotID: snapshot.id, seed: saved.seed), at: 0)
      } else if let request = pendingRequest {
        runs.insert(try await service.createRun(request, snapshotID: snapshot.id), at: 0)
      } else { return }
      snapshotPreview = nil; pendingRequest = nil
      pendingSavedScenario = nil
    } catch { errorMessage = "The scenario could not be queued." }
  }

  func discardSnapshot() { snapshotPreview = nil; pendingRequest = nil; pendingSavedScenario = nil }

  func deleteScenario(_ scenario: ScenarioDefinitionSummary) async {
    do { try await service.deleteScenario(id: scenario.id); scenarios.removeAll { $0.id == scenario.id } }
    catch { errorMessage = "The saved scenario could not be deleted." }
  }

  func createGoal(name: String, portfolioID: UUID?, targetAmount: Double?, targetDate: Date, currency: String,
                  monthlyContribution: Double?, contributionGrowth: Double?, inflation: Double?) async {
    guard !name.trimmingCharacters(in: .whitespaces).isEmpty, let portfolioID, let targetAmount, targetAmount > 0,
          let monthlyContribution, monthlyContribution >= 0, let contributionGrowth, let inflation, currency.count == 3 else {
      errorMessage = "Complete the financial goal with valid values."; return
    }
    do {
      goals.insert(try await service.createGoal(name: name, portfolioID: portfolioID, targetAmount: targetAmount, targetDate: targetDate,
                                                currency: currency, monthlyContribution: monthlyContribution,
                                                contributionGrowth: contributionGrowth / 100, inflation: inflation / 100), at: 0)
    } catch { errorMessage = "The financial goal could not be created." }
  }

  func deleteGoal(_ goal: ScenarioGoal) async {
    do { try await service.deleteGoal(id: goal.id); goals.removeAll { $0.id == goal.id } }
    catch { errorMessage = "The financial goal could not be deleted." }
  }

  func updateGoal(id: UUID, name: String, portfolioID: UUID?, targetAmount: Double?, targetDate: Date, currency: String,
                  monthlyContribution: Double?, contributionGrowth: Double?, inflation: Double?) async -> Bool {
    guard !name.trimmingCharacters(in: .whitespaces).isEmpty, let portfolioID, let targetAmount, targetAmount > 0,
          let monthlyContribution, monthlyContribution >= 0, let contributionGrowth, let inflation, currency.count == 3 else {
      errorMessage = "Complete the financial goal with valid values."; return false
    }
    do {
      let value = try await service.updateGoal(id: id, name: name, portfolioID: portfolioID, targetAmount: targetAmount,
        targetDate: targetDate, currency: currency, monthlyContribution: monthlyContribution,
        contributionGrowth: contributionGrowth / 100, inflation: inflation / 100)
      if let index = goals.firstIndex(where: { $0.id == id }) { goals[index] = value }
      return true
    } catch { errorMessage = "The financial goal could not be updated."; return false }
  }

  func saveRiskProfile(holdingID: UUID?, category: String, sector: String, region: String, benchmark: String,
                       manualValue: Double?, duration: Double?, convexity: Double?) async {
    guard let holdingID else { errorMessage = "Choose a holding for the risk profile."; return }
    do {
      let value = try await service.saveRiskProfile(holdingID: holdingID, assetCategory: category,
        sector: sector.nilIfScenarioBlank, region: region.nilIfScenarioBlank, benchmarkProxy: benchmark.nilIfScenarioBlank,
        manualValue: manualValue, duration: duration, convexity: convexity)
      riskProfiles.removeAll { $0.holdingId == holdingID }; riskProfiles.insert(value, at: 0)
    } catch { errorMessage = "The holding risk profile could not be saved." }
  }

  func deleteRiskProfile(_ profile: ScenarioRiskProfile) async {
    do { try await service.deleteRiskProfile(id: profile.id); riskProfiles.removeAll { $0.id == profile.id } }
    catch { errorMessage = "The holding risk profile could not be deleted." }
  }

  func poll() async {
    for index in runs.indices where ["queued", "running"].contains(runs[index].state) {
      if let updated = try? await service.run(id: runs[index].id) {
        runs[index] = updated
      }
    }
  }

  func cancel(_ run: ScenarioRunSummary) async {
    do {
      try await service.cancel(runID: run.id)
      await poll()
    } catch {
      errorMessage = "The run could not be cancelled."
    }
  }
}

// MARK: - Screen

struct ScenarioPlanningScreen: View {
  @State private var model: ScenarioPlanningViewModel
  @State private var kind = ScenarioBuilderKind.historical
  @State private var name = "Portfolio stress test"
  @State private var portfolioID: UUID?
  @State private var baseCurrency = "USD"
  @State private var selectedCryptoHoldingIDs: Set<UUID> = []
  @State private var goalID: UUID?
  @State private var preset = "covid_crash"
  @State private var shock = -0.2
  @State private var assetClassTarget = "stock"
  @State private var holdingShockTarget = ""
  @State private var holdingShock = ""
  @State private var sectorShockTarget = ""
  @State private var sectorShock = ""
  @State private var regionShockTarget = ""
  @State private var regionShock = ""
  @State private var currencyShockTarget = ""
  @State private var currencyShock = ""
  @State private var rateShiftBps = "0"
  @State private var volatilityMultiplier = "1"
  @State private var recovery = "linear"
  @State private var horizon = 360
  @State private var paths = 10_000
  @State private var distribution = "block_bootstrap"
  @State private var seed = ""
  @State private var assetWeights = ""
  @State private var assetAnnualReturns = ""
  @State private var annualCovariance = ""
  @State private var saveConfiguration = true
  @State private var savedScenarioSeed = ""
  @State private var selected: Set<UUID> = []
  @State private var comparisonMode = ScenarioComparisonMode.value
  @State private var reports: [UUID: URL] = [:]
  @State private var riskHoldingID: UUID?
  @State private var riskCategory = "stock"
  @State private var riskSector = ""
  @State private var riskRegion = ""
  @State private var riskBenchmark = ""
  @State private var riskManualValue = ""
  @State private var riskDuration = ""
  @State private var riskConvexity = ""

  init() {
    let c = Container.shared
    _model = State(initialValue: ScenarioPlanningViewModel(
      service: ScenarioPlanningService(
        environment: c.appEnvironment(),
        auth: c.authSessionManager()
      )
    ))
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 24) {
        if model.isLoading && model.catalog == nil {
          ProgressView()
            .frame(maxWidth: .infinity, minHeight: 180)
        }
        if let catalog = model.catalog {
          builder(catalog)
        }
        if selected.count > 1 {
          comparison
        }
        management
        runsSection
      }
      .padding(16)
    }
    .navigationTitle("Scenario planning")
    .navigationBarTitleDisplayMode(.inline)
    .task { await model.load() }
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(2))
        await model.poll()
      }
    }
    .refreshable { await model.load() }
    .sheet(item: $model.snapshotPreview) { snapshot in
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            Text("Prices, FX rates, classifications, and risk metadata are frozen for this run.").foregroundStyle(.secondary)
            snapshotSection("Data-quality and proxy warnings", value: snapshot.warnings)
            snapshotSection("Frozen holdings and valuations", value: snapshot.payload)
          }.padding(16)
        }
        .navigationTitle("Review snapshot").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.discardSnapshot() } }
          ToolbarItem(placement: .confirmationAction) { Button("Run") { Task { await model.runReviewedSnapshot() } }.disabled(model.isSubmitting) }
        }
      }
    }
    .alert(
      "Scenario planning",
      isPresented: Binding(
        get: { model.errorMessage != nil },
        set: { if !$0 { model.errorMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(model.errorMessage ?? "")
    }
  }

  // MARK: - Builder

  private func builder(_ catalog: ScenarioCatalogPayload) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionLabel("NEW RUN")
      VStack(spacing: 16) {
        TextField("Scenario name", text: $name)
          .textFieldStyle(.roundedBorder)

        Picker("Portfolio", selection: $portfolioID) {
          Text("Choose portfolio").tag(UUID?.none)
          ForEach(model.portfolios) {
            Text($0.name).tag(Optional($0.id))
          }
        }

        TextField("Snapshot base currency", text: $baseCurrency)
          .textInputAutocapitalization(.characters)
          .autocorrectionDisabled()
          .textFieldStyle(.roundedBorder)

        cryptoHoldingSelection

        Picker("Type", selection: $kind) {
          ForEach(ScenarioBuilderKind.allCases) {
            Text($0.title).tag($0)
          }
        }
        .pickerStyle(.segmented)

        builderKindOptions(catalog)

        Picker("Goal", selection: $goalID) {
          Text("No linked goal").tag(UUID?.none)
          ForEach(model.goals) {
            Text($0.name).tag(Optional($0.id))
          }
        }

        TextField("Random seed", text: $seed)
          .keyboardType(.numberPad)
          .textFieldStyle(.roundedBorder)

        Toggle("Save configuration", isOn: $saveConfiguration)

        Button {
          Task { await submit() }
        } label: {
          Group {
            if model.isSubmitting {
              ProgressView()
            } else {
              Text("Review snapshot")
            }
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(portfolioID == nil || model.isSubmitting)
      }
      .card()
    }
  }

  @ViewBuilder
  private func builderKindOptions(_ catalog: ScenarioCatalogPayload) -> some View {
    if kind == .historical {
      Picker("Historical event", selection: $preset) {
        ForEach(catalog.historicalScenarios) {
          Text($0.name).tag($0.id)
        }
      }
    } else if kind == .custom {
      Picker("Asset class", selection: $assetClassTarget) {
        ForEach(["stock", "etf", "mutual_fund", "crypto", "cash", "bond", "real_estate", "commodity"], id: \.self) {
          Text($0.replacingOccurrences(of: "_", with: " ").capitalized).tag($0)
        }
      }
      Text("Asset-class shock: \(shock, format: .percent.precision(.fractionLength(0)))")
      Slider(value: $shock, in: -1...1, step: 0.01)
      Stepper("Horizon: \(min(horizon, 120)) months", value: $horizon, in: 1...120)
      Picker("Recovery", selection: $recovery) {
        Text("None").tag("none"); Text("Linear").tag("linear"); Text("Mean reverting").tag("mean_reverting")
      }
      HStack {
        TextField("Rate shift (bps)", text: $rateShiftBps).keyboardType(.numbersAndPunctuation).textFieldStyle(.roundedBorder)
        TextField("Volatility multiplier", text: $volatilityMultiplier).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
      }
      DisclosureGroup("Scoped shocks") {
        VStack(spacing: 10) {
          scopedShockEditor("Holding ID", target: $holdingShockTarget, percentage: $holdingShock)
          scopedShockEditor("Sector", target: $sectorShockTarget, percentage: $sectorShock)
          scopedShockEditor("Region", target: $regionShockTarget, percentage: $regionShock)
          scopedShockEditor("Currency", target: $currencyShockTarget, percentage: $currencyShock)
          Text("Applicable shocks compound. A holding shock overrides broader percentage shocks.")
            .font(.caption).foregroundStyle(.secondary)
        }.padding(.top, 8)
      }
    } else {
      Picker("Distribution", selection: $distribution) {
        Text("Block bootstrap").tag("block_bootstrap")
        Text("Normal").tag("normal")
        Text("Student-t").tag("student_t")
      }
      Stepper("Paths: \(paths.formatted())", value: $paths, in: 1_000...50_000, step: 1_000)
      Stepper("Horizon: \(horizon) months", value: $horizon, in: 1...600)
      DisclosureGroup("Correlated multi-asset assumptions") {
        VStack(alignment: .leading, spacing: 12) {
          assumptionEditor("Weights", example: "[0.6, 0.4]", text: $assetWeights)
          assumptionEditor("Annual returns", example: "[0.08, 0.04]", text: $assetAnnualReturns)
          assumptionEditor("Annual covariance matrix", example: "[[0.04, 0.006], [0.006, 0.01]]", text: $annualCovariance, minHeight: 88)
          Text("Optional. Provide all three JSON arrays; the server repairs non-positive-semidefinite covariance matrices before simulation.")
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.top, 8)
      }
    }
  }

  // MARK: - Runs

  private var management: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionLabel("REUSABLE INPUTS")
      DisclosureGroup("Saved scenarios") {
        VStack(spacing: 12) {
          TextField("Random seed (optional)", text: $savedScenarioSeed)
            .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
          TextField("Snapshot base currency", text: $baseCurrency)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .textFieldStyle(.roundedBorder)
          cryptoHoldingSelection
          ForEach(model.scenarios.filter { $0.isSaved ?? true }) { scenario in
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                VStack(alignment: .leading) {
                  Text(scenario.name).font(.headline)
                  Text(scenario.kind.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Delete", role: .destructive) { Task { await model.deleteScenario(scenario) } }
              }
              Button("Review snapshot and run") {
                Task {
                  await model.capture(
                    scenario,
                    seed: Int64(savedScenarioSeed),
                    baseCurrency: baseCurrency,
                    cryptoHoldingIDs: Array(selectedCryptoHoldingIDs)
                  )
                }
              }.buttonStyle(.bordered)
            }
            .padding(12)
            .background(Color(.tertiarySystemBackground))
            .clipShape(.rect(cornerRadius: 10))
          }
          if model.scenarios.allSatisfy({ !($0.isSaved ?? true) }) {
            Text("Save a configuration to reuse it here.").font(.subheadline).foregroundStyle(.secondary)
          }
        }.padding(.top, 12)
      }
      Divider()
      DisclosureGroup("Holding risk profiles") {
        VStack(spacing: 12) {
          Picker("Holding", selection: $riskHoldingID) { Text("Choose holding").tag(UUID?.none); ForEach(model.holdings) { Text("\($0.symbol) · \($0.category)").tag(Optional($0.id)) } }
          Picker("Asset class", selection: $riskCategory) { ForEach(["stock", "etf", "mutual_fund", "crypto", "cash", "bond", "real_estate", "commodity"], id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized).tag($0) } }
          TextField("Benchmark proxy", text: $riskBenchmark).textInputAutocapitalization(.characters).textFieldStyle(.roundedBorder)
          TextField("Sector", text: $riskSector).textFieldStyle(.roundedBorder)
          TextField("Region", text: $riskRegion).textFieldStyle(.roundedBorder)
          TextField("Manual value (optional)", text: $riskManualValue).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
          TextField("Duration (optional)", text: $riskDuration).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
          TextField("Convexity (optional)", text: $riskConvexity).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
          Button("Save risk profile") { Task { await model.saveRiskProfile(holdingID: riskHoldingID, category: riskCategory, sector: riskSector, region: riskRegion, benchmark: riskBenchmark, manualValue: Double(riskManualValue), duration: Double(riskDuration), convexity: Double(riskConvexity)) } }.buttonStyle(.borderedProminent)
          ForEach(model.riskProfiles) { profile in HStack { Text(profile.assetCategory.replacingOccurrences(of: "_", with: " ").capitalized); Spacer(); Button("Delete", role: .destructive) { Task { await model.deleteRiskProfile(profile) } } } }
        }.padding(.top, 12)
      }
    }.card()
  }

  // MARK: - Runs

  private var runsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionLabel("RECENT RUNS")
      if model.runs.isEmpty {
        ContentUnavailableView("No scenarios yet", systemImage: "chart.xyaxis.line")
      }
      ForEach(model.runs) { runCard($0) }
    }
  }

  private func runCard(_ run: ScenarioRunSummary) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      runCardHeader(run)
      ProgressView(value: run.progress)
      if let result = run.result {
        runCardResult(run: run, result: result)
      }
      if run.state == "completed" {
        runComparisonToggle(run)
      }
    }
    .card()
  }

  private func runCardHeader(_ run: ScenarioRunSummary) -> some View {
    HStack {
      Text(run.state.capitalized)
        .font(.headline)
      Spacer()
      Text(run.progress, format: .percent.precision(.fractionLength(0)))
      if ["queued", "running"].contains(run.state) {
        Button("Cancel", role: .destructive) {
          Task { await model.cancel(run) }
        }
      }
    }
  }

  private func runCardResult(run: ScenarioRunSummary, result: ScenarioResultPayload) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      if let probability = result.goalProbability {
        Gauge(value: probability) {
          Text("Goal probability")
        } currentValueLabel: {
          Text(probability, format: .percent.precision(.fractionLength(0)))
        }
        .gaugeStyle(.accessoryCircularCapacity)
      }
      if let points = result.timeline {
        Chart(points) {
          LineMark(
            x: .value("Month", $0.elapsedMonths),
            y: .value("Value", $0.value)
          )
        }
        .frame(height: 140)
      } else if let bands = result.percentileBands {
        Chart(bands) { band in
          AreaMark(
            x: .value("Month", band.elapsedMonths),
            yStart: .value("10th percentile", band.p10),
            yEnd: .value("90th percentile", band.p90)
          ).foregroundStyle(.blue.opacity(0.16))
          LineMark(x: .value("Month", band.elapsedMonths), y: .value("Median", band.p50))
            .foregroundStyle(.blue)
        }
        .frame(height: 140)
        .accessibilityLabel("Portfolio value percentile fan")
      }
      if let url = reports[run.id] {
        ShareLink(item: url) {
          Label("Share private PDF", systemImage: "square.and.arrow.up")
        }
      } else {
        Button("Create private PDF", systemImage: "doc.richtext") {
          reports[run.id] = try? ScenarioPDFReport.render(run: run, result: result)
        }
      }
    }
  }

  private func runComparisonToggle(_ run: ScenarioRunSummary) -> some View {
    let isSelected = selected.contains(run.id)
    let label = isSelected ? "Remove from comparison" : "Add to comparison"
    let icon = isSelected ? "checkmark.circle.fill" : "circle"
    return Button(label, systemImage: icon) {
      if isSelected {
        selected.remove(run.id)
      } else if selected.count < 4 {
        selected.insert(run.id)
      }
    }
    .disabled(!isSelected && selected.count == 4)
  }

  // MARK: - Comparison

  private var comparison: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionLabel("COMPARISON · \(selected.count) OF 4")
      Picker("Comparison view", selection: $comparisonMode) {
        ForEach(ScenarioComparisonMode.allCases) { Text($0.title).tag($0) }
      }
      .pickerStyle(.segmented)
      comparisonChart
        .frame(height: 220)
        .chartLegend(position: .bottom)
    }
    .card()
  }

  private var comparisonChart: some View {
    let filteredRuns = model.runs.filter { selected.contains($0.id) }
    return Chart {
      ForEach(filteredRuns) { run in
        let seriesLabel = String(run.id.uuidString.prefix(8))
        if comparisonMode == .drawdown, let value = run.result?.maximumDrawdown {
          BarMark(x: .value("Run", seriesLabel), y: .value("Drawdown", value))
            .foregroundStyle(by: .value("Run", seriesLabel))
        } else if comparisonMode == .goal, let value = run.result?.goalProbability {
          BarMark(x: .value("Run", seriesLabel), y: .value("Probability", value))
            .foregroundStyle(by: .value("Run", seriesLabel))
        } else if comparisonMode == .fan {
          ForEach(run.result?.percentileBands ?? []) { band in
            AreaMark(
              x: .value("Month", band.elapsedMonths),
              yStart: .value("P10", band.p10), yEnd: .value("P90", band.p90),
              series: .value("Run", run.id.uuidString)
            ).foregroundStyle(by: .value("Run", seriesLabel)).opacity(0.14)
            LineMark(x: .value("Month", band.elapsedMonths), y: .value("Median", band.p50), series: .value("Run", run.id.uuidString))
              .foregroundStyle(by: .value("Run", seriesLabel))
          }
        } else {
          let points = run.result?.timeline ?? []
          let initial = points.first?.value ?? 0
          ForEach(points) { point in
            LineMark(
              x: .value("Month", point.elapsedMonths),
              y: .value(comparisonMode == .return ? "Return" : "Value", comparisonMode == .return && initial != 0 ? point.value / initial - 1 : point.value),
              series: .value("Run", run.id.uuidString)
            )
            .foregroundStyle(by: .value("Run", seriesLabel))
          }
        }
      }
    }
  }

  // MARK: - Helpers

  private func submit() async {
    let normalizedCurrency = baseCurrency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard normalizedCurrency.count == 3 else {
      model.errorMessage = "Enter a valid three-letter snapshot currency."
      return
    }
    guard let portfolioID else { return }
    let assumptions: (weights: [Double], annualReturns: [Double], covariance: [[Double]])
    do {
      assumptions = try parseScenarioMultiAssetAssumptions(
        weights: assetWeights,
        annualReturns: assetAnnualReturns,
        covariance: annualCovariance
      )
    } catch {
      model.errorMessage = error.localizedDescription
      return
    }
    let scoped: [(String?, Double?)]
    do {
      scoped = try [
        parseScenarioScopedShock(target: holdingShockTarget, percentage: holdingShock),
        parseScenarioScopedShock(target: sectorShockTarget, percentage: sectorShock),
        parseScenarioScopedShock(target: regionShockTarget, percentage: regionShock),
        parseScenarioScopedShock(target: currencyShockTarget, percentage: currencyShock),
      ]
    } catch {
      model.errorMessage = error.localizedDescription
      return
    }
    guard let rateShift = Double(rateShiftBps), (-5000...5000).contains(rateShift),
          let volatility = Double(volatilityMultiplier), (0...10).contains(volatility) else {
      model.errorMessage = "Rate shift or volatility multiplier is outside the supported range."
      return
    }
    await model.capture(.init(
      name: name,
      portfolioID: portfolioID,
      goalID: goalID,
      kind: kind,
      catalogID: preset,
      shock: shock,
      horizonMonths: kind == .custom ? min(horizon, 120) : horizon,
      pathCount: paths,
      distribution: distribution,
      seed: Int64(seed),
      save: saveConfiguration,
      assetWeights: assumptions.weights,
      assetAnnualReturns: assumptions.annualReturns,
      annualCovariance: assumptions.covariance,
      assetClassTarget: assetClassTarget,
      holdingShockTarget: scoped[0].0, holdingShock: scoped[0].1,
      sectorShockTarget: scoped[1].0, sectorShock: scoped[1].1,
      regionShockTarget: scoped[2].0, regionShock: scoped[2].1,
      currencyShockTarget: scoped[3].0, currencyShock: scoped[3].1,
      parallelRateShiftBps: rateShift, volatilityMultiplier: volatility, recovery: recovery
    ), baseCurrency: normalizedCurrency, cryptoHoldingIDs: Array(selectedCryptoHoldingIDs))
  }

  @ViewBuilder
  private var cryptoHoldingSelection: some View {
    if !model.cryptoHoldings.isEmpty {
      DisclosureGroup("Include crypto holdings") {
        VStack(alignment: .leading, spacing: 10) {
          ForEach(model.cryptoHoldings) { holding in
            Toggle(isOn: Binding(
              get: { selectedCryptoHoldingIDs.contains(holding.id) },
              set: { selected in
                if selected { selectedCryptoHoldingIDs.insert(holding.id) }
                else { selectedCryptoHoldingIDs.remove(holding.id) }
              }
            )) {
              HStack {
                Text(holding.symbol).fontWeight(.medium)
                Text(holding.quantity, format: .number.precision(.significantDigits(1...8)))
                  .foregroundStyle(.secondary)
              }
            }
          }
          Text("Only selected crypto holdings are frozen into the snapshot.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
      }
    }
  }

  private func scopedShockEditor(_ label: String, target: Binding<String>, percentage: Binding<String>) -> some View {
    HStack {
      TextField(label, text: target).textFieldStyle(.roundedBorder)
      TextField("Shock %", text: percentage).keyboardType(.numbersAndPunctuation).textFieldStyle(.roundedBorder)
    }
  }

  private func assumptionEditor(
    _ title: String,
    example: String,
    text: Binding<String>,
    minHeight: CGFloat = 48
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title).font(.subheadline.weight(.medium))
      TextEditor(text: text)
        .font(.system(.caption, design: .monospaced))
        .frame(minHeight: minHeight)
        .padding(6)
        .background(Color(.tertiarySystemBackground))
        .clipShape(.rect(cornerRadius: 8))
        .overlay(alignment: .topLeading) {
          if text.wrappedValue.isEmpty {
            Text(example).font(.system(.caption, design: .monospaced)).foregroundStyle(.tertiary).padding(11).allowsHitTesting(false)
          }
        }
        .accessibilityLabel(title)
    }
  }

  private func snapshotSection(_ title: String, value: ScenarioJSONValue?) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.headline)
      Text(value?.description ?? "None")
        .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(Color(.secondarySystemBackground)).clipShape(.rect(cornerRadius: 10))
    }
  }

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(.caption.weight(.medium))
      .tracking(1.5)
      .foregroundStyle(.secondary)
  }
}

private enum ScenarioComparisonMode: String, CaseIterable, Identifiable {
  case value, `return`, fan, drawdown, goal
  var id: String { rawValue }
  var title: String {
    switch self { case .value: "Value"; case .return: "Return"; case .fan: "Fan"; case .drawdown: "Drawdown"; case .goal: "Goal" }
  }
}

// MARK: - View extension

private extension View {
  func card() -> some View {
    padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(.secondarySystemBackground))
      .clipShape(.rect(cornerRadius: 10))
  }
}

private extension String {
  var nilIfScenarioBlank: String? {
    let value = trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }
}

private enum ScenarioScopedShockError: LocalizedError {
  case incomplete, invalidPercentage
  var errorDescription: String? {
    switch self {
    case .incomplete: "Provide both a scoped shock target and percentage."
    case .invalidPercentage: "Scoped shock percentages must be between -100% and 100%."
    }
  }
}

private func parseScenarioScopedShock(target: String, percentage: String) throws -> (String?, Double?) {
  let target = target.trimmingCharacters(in: .whitespacesAndNewlines)
  let percentage = percentage.trimmingCharacters(in: .whitespacesAndNewlines)
  if target.isEmpty, percentage.isEmpty { return (nil, nil) }
  guard !target.isEmpty, !percentage.isEmpty else { throw ScenarioScopedShockError.incomplete }
  guard let value = Double(percentage), (-100...100).contains(value) else { throw ScenarioScopedShockError.invalidPercentage }
  return (target, value / 100)
}
