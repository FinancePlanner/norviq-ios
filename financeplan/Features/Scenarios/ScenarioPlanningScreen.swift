import Charts
import Factory
import Observation
import SwiftUI

@MainActor @Observable final class ScenarioPlanningViewModel {
  var catalog: ScenarioCatalogPayload?; var runs: [ScenarioRunSummary] = []; var portfolios: [ScenarioPortfolio] = []; var goals: [ScenarioGoal] = []
  var isLoading = false; var isSubmitting = false; var errorMessage: String?; private let service: ScenarioPlanningServiceProtocol
  init(service: ScenarioPlanningServiceProtocol) { self.service = service }
  func load() async { isLoading = true; defer { isLoading = false }; do { async let c = service.catalog(); async let r = service.runs(); async let p = service.portfolios(); async let g = service.goals(); catalog = try await c; runs = try await r; portfolios = try await p; goals = try await g } catch { errorMessage = "Scenario planning is temporarily unavailable." } }
  func submit(_ request: ScenarioRunRequest) async { isSubmitting = true; defer { isSubmitting = false }; do { runs.insert(try await service.createRun(request), at: 0) } catch { errorMessage = "The scenario could not be queued." } }
  func poll() async { for index in runs.indices where ["queued", "running"].contains(runs[index].state) { if let updated = try? await service.run(id: runs[index].id) { runs[index] = updated } } }
  func cancel(_ run: ScenarioRunSummary) async { do { try await service.cancel(runID: run.id); await poll() } catch { errorMessage = "The run could not be cancelled." } }
}

struct ScenarioPlanningScreen: View {
  @State private var model: ScenarioPlanningViewModel
  @State private var kind = ScenarioBuilderKind.historical; @State private var name = "Portfolio stress test"; @State private var portfolioID: UUID?; @State private var goalID: UUID?
  @State private var preset = "covid_crash"; @State private var shock = -0.2; @State private var horizon = 360; @State private var paths = 10_000; @State private var distribution = "block_bootstrap"; @State private var seed = ""; @State private var selected: Set<UUID> = []; @State private var reports: [UUID: URL] = [:]
  init() { let c = Container.shared; _model = State(initialValue: ScenarioPlanningViewModel(service: ScenarioPlanningService(environment: c.appEnvironment(), auth: c.authSessionManager()))) }
  var body: some View {
    ScrollView { LazyVStack(alignment: .leading, spacing: 24) { if model.isLoading && model.catalog == nil { ProgressView().frame(maxWidth: .infinity, minHeight: 180) }; if let catalog = model.catalog { builder(catalog) }; if selected.count > 1 { comparison }; runs }.padding(16) }
      .navigationTitle("Scenario planning").navigationBarTitleDisplayMode(.inline).task { await model.load() }.task { while !Task.isCancelled { try? await Task.sleep(for: .seconds(2)); await model.poll() } }.refreshable { await model.load() }
      .alert("Scenario planning", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(model.errorMessage ?? "") }
  }
  private func builder(_ catalog: ScenarioCatalogPayload) -> some View {
    VStack(alignment: .leading, spacing: 12) { sectionLabel("NEW RUN"); VStack(spacing: 16) {
      TextField("Scenario name", text: $name).textFieldStyle(.roundedBorder)
      Picker("Portfolio", selection: $portfolioID) { Text("Choose portfolio").tag(UUID?.none); ForEach(model.portfolios) { Text($0.name).tag(Optional($0.id)) } }
      Picker("Type", selection: $kind) { ForEach(ScenarioBuilderKind.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
      if kind == .historical { Picker("Historical event", selection: $preset) { ForEach(catalog.historicalScenarios) { Text($0.name).tag($0.id) } } }
      else if kind == .custom { Text("Stock shock: \(shock, format: .percent.precision(.fractionLength(0)))"); Slider(value: $shock, in: -1...1, step: 0.01); Stepper("Horizon: \(min(horizon, 120)) months", value: $horizon, in: 1...120) }
      else { Picker("Distribution", selection: $distribution) { Text("Block bootstrap").tag("block_bootstrap"); Text("Normal").tag("normal"); Text("Student-t").tag("student_t") }; Stepper("Paths: \(paths.formatted())", value: $paths, in: 1_000...50_000, step: 1_000); Stepper("Horizon: \(horizon) months", value: $horizon, in: 1...600) }
      Picker("Goal", selection: $goalID) { Text("No linked goal").tag(UUID?.none); ForEach(model.goals) { Text($0.name).tag(Optional($0.id)) } }; TextField("Random seed", text: $seed).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
      Button { Task { await submit() } } label: { Group { if model.isSubmitting { ProgressView() } else { Text("Capture snapshot and run") } }.frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).disabled(portfolioID == nil || model.isSubmitting)
    }.card() }
  }
  private var runs: some View { VStack(alignment: .leading, spacing: 12) { sectionLabel("RECENT RUNS"); if model.runs.isEmpty { ContentUnavailableView("No scenarios yet", systemImage: "chart.xyaxis.line") }; ForEach(model.runs) { runCard($0) } } }
  private func runCard(_ run: ScenarioRunSummary) -> some View { VStack(alignment: .leading, spacing: 12) { HStack { Text(run.state.capitalized).font(.headline); Spacer(); Text(run.progress, format: .percent.precision(.fractionLength(0))); if ["queued", "running"].contains(run.state) { Button("Cancel", role: .destructive) { Task { await model.cancel(run) } } } }; ProgressView(value: run.progress)
    if let result = run.result { if let probability = result.goalProbability { Gauge(value: probability) { Text("Goal probability") } currentValueLabel: { Text(probability, format: .percent.precision(.fractionLength(0))) }.gaugeStyle(.accessoryCircularCapacity) }; if let points = result.timeline { Chart(points) { LineMark(x: .value("Month", $0.elapsedMonths), y: .value("Value", $0.value)) }.frame(height: 140) }; if let url = reports[run.id] { ShareLink(item: url) { Label("Share private PDF", systemImage: "square.and.arrow.up") } } else { Button("Create private PDF", systemImage: "doc.richtext") { reports[run.id] = try? ScenarioPDFReport.render(run: run, result: result) } } }
    if run.state == "completed" { Button(selected.contains(run.id) ? "Remove from comparison" : "Add to comparison", systemImage: selected.contains(run.id) ? "checkmark.circle.fill" : "circle") { if selected.contains(run.id) { selected.remove(run.id) } else if selected.count < 4 { selected.insert(run.id) } }.disabled(!selected.contains(run.id) && selected.count == 4) }
  }.card() }
  private var comparison: some View { VStack(alignment: .leading, spacing: 12) { sectionLabel("COMPARISON · \(selected.count) OF 4"); Chart { ForEach(model.runs.filter { selected.contains($0.id) }) { run in ForEach(run.result?.timeline ?? []) { point in LineMark(x: .value("Month", point.elapsedMonths), y: .value("Value", point.value), series: .value("Run", run.id.uuidString)).foregroundStyle(by: .value("Run", String(run.id.uuidString.prefix(8)))) } } }.frame(height: 220).chartLegend(position: .bottom) }.card() }
  private func submit() async { guard let portfolioID else { return }; await model.submit(.init(name: name, portfolioID: portfolioID, goalID: goalID, kind: kind, catalogID: preset, shock: shock, horizonMonths: kind == .custom ? min(horizon, 120) : horizon, pathCount: paths, distribution: distribution, seed: Int64(seed), save: true)) }
  private func sectionLabel(_ text: String) -> some View { Text(text).font(.caption.weight(.medium)).tracking(1.5).foregroundStyle(.secondary) }
}

private extension View { func card() -> some View { padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Color(.secondarySystemBackground)).clipShape(.rect(cornerRadius: 10)) } }
