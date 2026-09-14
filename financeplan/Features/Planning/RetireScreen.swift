import Charts
import Factory
import StockPlanShared
import SwiftUI

/// Retire: what life costs, what that means you need, and the exact move that closes the gap.
struct RetireScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var model: RetireViewModel

  init(model: RetireViewModel = RetireViewModel(service: Container.shared.planningService())) {
    _model = State(initialValue: model)
  }

  var body: some View {
    @Bindable var model = model

    ScrollView {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
        VigilPageHeader(
          watch: .wealthPlan,
          title: "Retire",
          subtitle: "What your life costs, and the shortest way to afford it."
        )

        if model.hasBudget == false {
          noBudgetNotice
        }

        headline
        leverCard
        chart
        lifeInputs(model: $model)
        planInputs(model: $model)
        assumptions
      }
      .padding(.horizontal, AppTheme.Spacing.md)
      .padding(.bottom, AppTheme.Spacing.xxl)
      .maxContentWidth(regularSizeClass: ContentWidth.dense)
    }
    .vigilScreenBackground()
    .vigilNavigationTitle("Retire")
    .vigilInlineNavigationBar()
    .task { await model.loadPrefill() }
  }

  private var noBudgetNotice: some View {
    GlassCard {
      Text("There is no budget to read your cost of life from yet, so this starts from a typical month rather than yours.")
        .typography(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var verdictColor: Color {
    switch model.verdict {
    case .onTrack: AppTheme.Colors.successText(for: colorScheme)
    case .shortButLasts: AppTheme.Colors.warningText(for: colorScheme)
    case .runsOut: AppTheme.Colors.dangerText(for: colorScheme)
    }
  }

  private var verdictLabel: LocalizedStringKey {
    switch model.verdict {
    case .onTrack: "Your plan covers this"
    case .shortButLasts: "Short of the target, but the money lasts"
    case .runsOut: "Short, and the money runs out"
    }
  }

  private var headline: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
        Text("You will need")
          .typography(.overline)
          .foregroundStyle(.secondary)

        Text(model.need?.nestEggAtWithdrawalRate ?? 0,
             format: .currency(code: model.currency).precision(.fractionLength(0)))
          .typography(.displayNumber)
          .contentTransition(.numericText())

        Text(verdictLabel)
          .typography(.footnote)
          .foregroundStyle(verdictColor)

        HStack(spacing: AppTheme.Spacing.lg) {
          VStack(alignment: .leading, spacing: 2) {
            Text("You will have").typography(.overline).foregroundStyle(.secondary)
            Text(model.projectedAtRetirement,
                 format: .currency(code: model.currency).precision(.fractionLength(0)))
              .typography(.metricNumber)
          }
          if let lever = model.lever {
            VStack(alignment: .leading, spacing: 2) {
              Text(lever.isOnTrack ? "Surplus" : "Gap")
                .typography(.overline).foregroundStyle(.secondary)
              Text(abs(lever.gap), format: .currency(code: model.currency).precision(.fractionLength(0)))
                .typography(.metricNumber)
                .foregroundStyle(verdictColor)
            }
          }
        }
        .padding(.top, AppTheme.Spacing.xs)

        runwayLine
        probabilityRow
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder private var runwayLine: some View {
    if let need = model.need {
      if let shortfall = need.shortfallAge {
        Text("The money runs out at \(shortfall), after \(need.runwayYears) years of retirement.")
          .typography(.nano)
          .foregroundStyle(.secondary)
      } else {
        Text("The money lasts the full \(need.runwayYears) years.")
          .typography(.nano)
          .foregroundStyle(.secondary)
      }
    }
  }

  /// The probability is a Monte Carlo run on the server, so it is asked for rather than
  /// computed on every keystroke.
  @ViewBuilder private var probabilityRow: some View {
    HStack {
      if let probability = model.readinessProbability {
        Text("Lasts to \(model.longevityAge) in \(probability.formatted(.percent.precision(.fractionLength(0)))) of simulated markets")
          .typography(.nano)
          .foregroundStyle(.secondary)
      } else {
        Button {
          Task { await model.checkProbability() }
        } label: {
          if model.isCheckingProbability {
            ProgressView().controlSize(.small)
          } else {
            Text("Check the odds").typography(.nano)
          }
        }
        .disabled(model.isCheckingProbability)
      }
    }
    .padding(.top, AppTheme.Spacing.xs)
  }

  /// The reason this screen exists. A gap on its own is forgettable.
  @ViewBuilder private var leverCard: some View {
    if let lever = model.lever, lever.isOnTrack == false {
      GlassCard {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
          Text("To close it, any one of these")
            .typography(.small, weight: .semibold)

          if let extra = lever.additionalMonthlyContribution, extra > 0 {
            leverRow(
              value: "+" + extra.formatted(.currency(code: model.currency).precision(.fractionLength(0))) + String(localized: " a month"),
              detail: "on top of what you already put away"
            )
          }
          if let delay = lever.delayYears, delay > 0 {
            leverRow(
              value: delay == 1 ? String(localized: "Retire 1 year later") : String(localized: "Retire \(delay) years later"),
              detail: "more years of saving, and fewer to fund"
            )
          }
          if let reduction = lever.spendingReductionMonthly, reduction > 0 {
            leverRow(
              value: "-" + reduction.formatted(.currency(code: model.currency).precision(.fractionLength(0))) + String(localized: " a month"),
              detail: "spending less, in today's money"
            )
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private func leverRow(value: String, detail: LocalizedStringKey) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(value).typography(.metricNumber)
      Text(detail).typography(.nano).foregroundStyle(.secondary)
    }
  }

  @ViewBuilder private var chart: some View {
    if let need = model.need, need.depletion.count > 1 {
      ChartCard(
        title: String(localized: "In retirement"),
        subtitle: String(localized: "What is left, against what it has to fund")
      ) {
        Chart {
          ForEach(need.depletion) { year in
            AreaMark(
              x: .value("Age", year.age),
              y: .value("Left", year.endingBalance)
            )
            .foregroundStyle(AppTheme.Colors.tint.opacity(0.15))

            LineMark(
              x: .value("Age", year.age),
              y: .value("Left", year.endingBalance)
            )
            .foregroundStyle(AppTheme.Colors.tint)
          }

          if let shortfall = need.shortfallAge {
            RuleMark(x: .value("Runs out", shortfall))
              .foregroundStyle(AppTheme.Colors.dangerText(for: colorScheme))
              .annotation(position: .top, alignment: .leading) {
                Text("runs out").typography(.nano)
              }
          }
        }
        .frame(height: 220)
        .accessibilityLabel("Portfolio balance through retirement")
      }
    }
  }

  private func lifeInputs(model: Bindable<RetireViewModel>) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
        Text("Your life").typography(.small, weight: .semibold)

        currencyField("Cost of life, monthly", value: model.monthlyCostOfLife)
        currencyField("Of which housing", value: model.monthlyHousing)

        Toggle("Housing ends at some point", isOn: Binding(
          get: { self.model.housingEndsAtAge != nil },
          set: { enabled in
            self.model.housingEndsAtAge = enabled ? self.model.retirementAge + 5 : nil
            self.model.recompute()
          }
        ))

        if let ends = self.model.housingEndsAtAge {
          Stepper(value: Binding(
            get: { ends },
            set: { self.model.housingEndsAtAge = $0; self.model.recompute() }
          ), in: self.model.currentAge ... self.model.longevityAge) {
            LabeledContent("Housing ends at age") { Text("\(ends)").typography(.numeric) }
          }
        }

        currencyField("Other retirement income, monthly", value: model.monthlyOtherIncome)
      }
    }
  }

  private func planInputs(model: Bindable<RetireViewModel>) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
        Text("Your plan").typography(.small, weight: .semibold)

        ageStepper("Age now", value: model.currentAge, range: 18 ... 99)
        ageStepper("Retire at", value: model.retirementAge, range: 19 ... 100)
        ageStepper("Plan to", value: model.longevityAge, range: 20 ... 120)

        currencyField("Invested today", value: model.investedToday)
        currencyField("Adding monthly", value: model.monthlyContribution)

        slider("Expected return", value: model.annualReturnRate, range: 0 ... 0.15, step: 0.005)
        slider("Inflation", value: model.annualInflationRate, range: 0 ... 0.10, step: 0.001)
        slider("Withdrawal rate", value: model.withdrawalRate, range: 0.01 ... 0.10, step: 0.0025)
      }
    }
  }

  private func ageStepper(_ label: LocalizedStringKey, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
    Stepper(value: value, in: range) {
      LabeledContent(label) { Text("\(value.wrappedValue)").typography(.numeric) }
    }
    .onChange(of: value.wrappedValue) { _, _ in model.recompute() }
  }

  private func currencyField(_ label: LocalizedStringKey, value: Binding<Double>) -> some View {
    LabeledContent(label) {
      TextField(
        label,
        value: value,
        format: .currency(code: model.currency).precision(.fractionLength(0))
      )
      .keyboardType(.decimalPad)
      .multilineTextAlignment(.trailing)
      .typography(.numeric)
      .onChange(of: value.wrappedValue) { _, _ in model.recompute() }
    }
  }

  private func slider(
    _ label: LocalizedStringKey,
    value: Binding<Double>,
    range: ClosedRange<Double>,
    step: Double
  ) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      LabeledContent(label) {
        Text(value.wrappedValue, format: .percent.precision(.fractionLength(2)))
          .typography(.numeric)
      }
      Slider(value: value, in: range, step: step)
        .onChange(of: value.wrappedValue) { _, _ in model.recompute() }
    }
  }

  private var assumptions: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
        Text("What this assumes").typography(.small, weight: .semibold)
        Text("Today's cost of life is carried forward to retirement at \(model.annualInflationRate.formatted(.percent.precision(.fractionLength(1)))) inflation a year.")
          .typography(.nano).foregroundStyle(.secondary)
        Text("The headline is annual spending divided by a \(model.withdrawalRate.formatted(.percent.precision(.fractionLength(2)))) withdrawal rate. The runway comes from spending the money down year by year, which is the one to trust when they disagree.")
          .typography(.nano).foregroundStyle(.secondary)
        Text("Projections, not advice.")
          .typography(.nano).foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
