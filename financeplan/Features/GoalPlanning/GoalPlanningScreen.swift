import Charts
import Factory
import StockPlanShared
import SwiftUI

struct GoalPlanningScreen: View {
  @Environment(\.dismiss) private var dismiss
  @State private var model = GoalPlanningViewModel(service: Container.shared.goalPlanningService())
  @State private var isCreatingGoal = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        overviewHeader
        if let overview = model.overview, overview.items.isEmpty {
          emptyState
        } else {
          goalsSection
          combinedTrajectory
        }
      }
      .padding(16)
      .maxContentWidth(regularSizeClass: ContentWidth.dense)
    }
    .background(MeshGradientBackground())
    .navigationTitle("Financial goals")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Close", systemImage: "xmark", action: dismiss.callAsFunction)
          .labelStyle(.iconOnly)
          .accessibilityLabel("Close financial goals")
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button("New goal", systemImage: "plus") { isCreatingGoal = true }
          .disabled(!model.canCreateActiveGoal)
          .accessibilityHint(model.canCreateActiveGoal ? "Opens the goal setup wizard" : "The free active-goal limit is reached")
      }
    }
    .overlay { if model.isLoading { ProgressView("Loading your plan…") } }
    .task { await model.load() }
    .refreshable { await model.load() }
    .sheet(isPresented: $isCreatingGoal) {
      NavigationStack {
        GoalCreationWizard(model: model) { isCreatingGoal = false }
      }
    }
    .alert("Goal planning", isPresented: Binding(
      get: { model.errorMessage != nil },
      set: { if !$0 { model.errorMessage = nil } }
    )) {
      Button("OK", role: .cancel) { model.errorMessage = nil }
    } message: {
      Text(model.errorMessage ?? "")
    }
  }

  private var overviewHeader: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Turn wealth into a plan")
        .font(.title2.bold())
      Text("Portfolio values, contribution habits, and spending choices stay connected to the outcomes you care about.")
        .foregroundStyle(.secondary)
      if let overview = model.overview {
        HStack(spacing: 24) {
          metric("Current", value: overview.totalCurrentValue)
          metric("Targets", value: overview.totalTargetAmount)
          VStack(alignment: .leading, spacing: 2) {
            Text("Active").font(.caption).foregroundStyle(.secondary)
            Text("\(overview.activeGoalCount)" + (overview.activeGoalLimit.map { "/\($0)" } ?? ""))
              .font(.headline.monospacedDigit())
          }
        }
      }
      if !model.canCreateActiveGoal {
        Label("Free includes one active goal. Pro unlocks unlimited goals and linked adjustments.", systemImage: "lock.fill")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var goalsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Your plan").font(.headline)
      ForEach(model.overview?.items ?? []) { item in
        NavigationLink {
          GoalDetailScreen(item: item, model: model)
        } label: {
          GoalOverviewCard(item: item)
        }
        .buttonStyle(.plain)
      }
    }
  }

  @ViewBuilder private var combinedTrajectory: some View {
    if let items = model.overview?.items, !items.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        Text("Projected outcomes").font(.headline)
        Chart(items) { item in
          BarMark(
            x: .value("Goal", item.goal.name),
            y: .value("Projected", item.progress.projectedValueAtTarget)
          )
          .foregroundStyle(by: .value("State", item.progress.driftState.rawValue))
          RuleMark(y: .value("Target", item.goal.targetAmount))
            .foregroundStyle(.secondary.opacity(0.35))
        }
        .frame(height: 210)
        .chartLegend(position: .bottom)
        Text("Bars use each goal’s deterministic return and observed contribution trajectory.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(16)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label("No financial goals", systemImage: "target")
    } description: {
      Text("Start with a target, timeline, and contribution plan. You can adjust every assumption later.")
    } actions: {
      Button("Create your first goal") { isCreatingGoal = true }
        .buttonStyle(.borderedProminent)
    }
  }

  private func metric(_ title: LocalizedStringKey, value: Double) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text(value, format: .currency(code: model.overview?.items.first?.goal.baseCurrency ?? "USD").presentation(.narrow))
        .font(.headline.monospacedDigit())
        .contentTransition(.numericText())
    }
  }
}

private struct GoalOverviewCard: View {
  @Environment(\.colorScheme) private var colorScheme
  let item: GoalOverviewItem

  var body: some View {
    HStack(spacing: 14) {
      Gauge(value: item.progress.percentComplete) {
        Text("Progress")
      } currentValueLabel: {
        Text(item.progress.percentComplete, format: .percent.precision(.fractionLength(0)))
          .font(.caption2.bold())
      }
      .gaugeStyle(.accessoryCircularCapacity)
      .tint(statusColor)
      .frame(width: 58)

      VStack(alignment: .leading, spacing: 5) {
        Text(item.goal.name).font(.headline)
        Text(item.goal.targetAmount, format: .currency(code: item.goal.baseCurrency).presentation(.narrow))
          .font(.subheadline.monospacedDigit())
        Label(statusText, systemImage: statusSymbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(statusColor)
      }
      Spacer()
      Image(systemName: "chevron.right").foregroundStyle(.tertiary)
    }
    .padding(16)
    .background(AppTheme.Colors.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .accessibilityElement(children: .combine)
  }

  private var statusText: String {
    switch item.progress.driftState {
    case .ahead: "Ahead"
    case .onTrack: "On track"
    case .behind: "Behind"
    case .complete: "Complete"
    case .insufficientData: "Building baseline"
    }
  }

  private var statusSymbol: String {
    switch item.progress.driftState {
    case .ahead: "arrow.up.right"
    case .onTrack, .complete: "checkmark.circle.fill"
    case .behind: "exclamationmark.circle.fill"
    case .insufficientData: "clock"
    }
  }

  private var statusColor: Color {
    switch item.progress.driftState {
    case .ahead, .onTrack, .complete: AppTheme.Colors.success
    case .behind: .orange
    case .insufficientData: .secondary
    }
  }
}
