import Factory
import Observation
import SwiftUI

@MainActor @Observable
final class ScenarioPlanningViewModel {
  var catalog: ScenarioCatalogPayload?
  var runs: [ScenarioRunSummary] = []
  var isLoading = false
  var errorMessage: String?
  private let service: ScenarioPlanningServiceProtocol

  init(service: ScenarioPlanningServiceProtocol) { self.service = service }

  func load() async {
    isLoading = true; defer { isLoading = false }
    do { async let catalog = service.catalog(); async let runs = service.runs(); self.catalog = try await catalog; self.runs = try await runs }
    catch { errorMessage = "Scenario planning is temporarily unavailable." }
  }

  func cancel(_ run: ScenarioRunSummary) async {
    do { try await service.cancel(runID: run.id); await load() }
    catch { errorMessage = "The run could not be cancelled." }
  }
}

struct ScenarioPlanningScreen: View {
  @State private var model: ScenarioPlanningViewModel

  init() {
    let container = Container.shared
    let service = ScenarioPlanningService(environment: container.appEnvironment(), auth: container.authSessionManager())
    _model = State(initialValue: ScenarioPlanningViewModel(service: service))
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 24) {
        if model.isLoading && model.catalog == nil { ProgressView().frame(maxWidth: .infinity, minHeight: 200) }
        if let catalog = model.catalog { historicalSection(catalog) }
        runsSection
      }
      .padding(16)
    }
    .navigationTitle("Scenario planning")
    .navigationBarTitleDisplayMode(.inline)
    .task { await model.load() }
    .refreshable { await model.load() }
    .alert("Scenario planning", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
      Button("OK", role: .cancel) {}
    } message: { Text(model.errorMessage ?? "") }
  }

  private func historicalSection(_ catalog: ScenarioCatalogPayload) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("HISTORICAL EVENTS").font(.caption.weight(.medium)).tracking(1.5).foregroundStyle(.secondary)
      ForEach(catalog.historicalScenarios) { item in
        VStack(alignment: .leading, spacing: 4) { Text(item.name).font(.headline); Text("\(item.startDate) – \(item.endDate)").font(.caption).foregroundStyle(.secondary) }
          .frame(maxWidth: .infinity, alignment: .leading).padding(16)
          .background(Color(.secondarySystemBackground)).clipShape(.rect(cornerRadius: 10))
      }
    }
  }

  private var runsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("RECENT RUNS").font(.caption.weight(.medium)).tracking(1.5).foregroundStyle(.secondary)
      if model.runs.isEmpty { ContentUnavailableView("No scenarios yet", systemImage: "chart.xyaxis.line", description: Text("Create a snapshot and scenario to begin.")) }
      ForEach(model.runs) { run in
        HStack(spacing: 12) {
          VStack(alignment: .leading, spacing: 4) { Text(run.state.capitalized).font(.headline); Text("Engine \(run.engineVersion)").font(.caption).foregroundStyle(.secondary) }
          Spacer(); Text(run.progress, format: .percent.precision(.fractionLength(0))).contentTransition(.numericText())
          if run.state == "queued" || run.state == "running" { Button("Cancel", role: .destructive) { Task { await model.cancel(run) } } }
        }
        .padding(16).background(Color(.secondarySystemBackground)).clipShape(.rect(cornerRadius: 10))
      }
    }
  }
}
