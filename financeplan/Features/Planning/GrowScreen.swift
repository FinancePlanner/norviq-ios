import Charts
import Factory
import StockPlanShared
import SwiftUI

/// Grow: what this money becomes. A big number, a chart, and the assumptions in plain sight.
struct GrowScreen: View {
  @State private var model: GrowViewModel

  init(model: GrowViewModel = GrowViewModel(service: Container.shared.planningService())) {
    _model = State(initialValue: model)
  }

  var body: some View {
    @Bindable var model = model

    ScrollView {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
        VigilPageHeader(
          watch: .wealthPlan,
          title: "Grow",
          subtitle: "What a plan becomes, under assumptions you can change."
        )

        headline
        chart
        inputs(model: $model)
        sensitivity
        assumptions
      }
      .padding(.horizontal, AppTheme.Spacing.md)
      .padding(.bottom, AppTheme.Spacing.xxl)
      .maxContentWidth(regularSizeClass: ContentWidth.dense)
    }
    .vigilScreenBackground()
    .vigilNavigationTitle("Grow")
    .vigilInlineNavigationBar()
    .task { await model.loadPrefill() }
  }

  private var headline: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
        Text(model.showInTodaysMoney ? "In today's money" : "Projected value")
          .typography(.overline)
          .foregroundStyle(.secondary)

        Text(model.headlineValue, format: .currency(code: model.currency).precision(.fractionLength(0)))
          .typography(.displayNumber)
          .contentTransition(.numericText())

        Text(secondaryLabel)
          .typography(.footnote)
          .foregroundStyle(.secondary)

        if let result = model.result {
          HStack(spacing: AppTheme.Spacing.lg) {
            metric("You put in", value: result.totalContributed)
            metric("Growth", value: result.totalGrowth)
            VStack(alignment: .leading, spacing: 2) {
              Text("Growth share").typography(.overline).foregroundStyle(.secondary)
              Text(model.growthShare, format: .percent.precision(.fractionLength(0)))
                .typography(.metricNumber)
            }
          }
          .padding(.top, AppTheme.Spacing.xs)
        }

        if model.prefilledFromPortfolio {
          Text("Starting amount taken from your portfolio.")
            .typography(.nano)
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var secondaryLabel: String {
    let other = model.secondaryValue.formatted(.currency(code: model.currency).precision(.fractionLength(0)))
    return model.showInTodaysMoney
      ? String(localized: "Before inflation: \(other).")
      : String(localized: "In today's money: \(other).")
  }

  private func metric(_ label: LocalizedStringKey, value: Double) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label).typography(.overline).foregroundStyle(.secondary)
      Text(value, format: .currency(code: model.currency).precision(.fractionLength(0)))
        .typography(.metricNumber)
    }
  }

  /// Three lines rather than one. The distance between the projected value and today's money
  /// is the part people underestimate, and it only reads if both are drawn.
  @ViewBuilder private var chart: some View {
    if let result = model.result, result.years.count > 1 {
      ChartCard(title: String(localized: "Over \(model.years) years")) {
        Chart {
          ForEach(result.years) { year in
            LineMark(
              x: .value("Year", year.yearIndex),
              y: .value("Value", year.endingBalanceNominal),
              series: .value("Series", "Projected")
            )
            .foregroundStyle(AppTheme.Colors.tint)

            LineMark(
              x: .value("Year", year.yearIndex),
              y: .value("Value", year.endingBalanceReal),
              series: .value("Series", "In today's money")
            )
            .foregroundStyle(AppTheme.Colors.secondaryTint)

            AreaMark(
              x: .value("Year", year.yearIndex),
              y: .value("Value", year.cumulativeContributions)
            )
            .foregroundStyle(AppTheme.Colors.tint.opacity(0.10))
          }
        }
        .chartLegend(.hidden)
        .frame(height: 220)
        .accessibilityLabel("Projected value against today's money and what you contributed")
      }
    }
  }

  private func inputs(model: Bindable<GrowViewModel>) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
        currencyField("Starting amount", value: model.initialAmount)
        currencyField("Monthly contribution", value: model.monthlyContribution)

        Stepper(value: model.years, in: 1 ... 60) {
          LabeledContent("Years") { Text("\(self.model.years)").typography(.numeric) }
        }
        .onChange(of: self.model.years) { _, _ in self.model.recompute() }

        slider("Expected return", value: model.annualReturnRate, range: 0 ... 0.15, step: 0.005)
        slider("Inflation", value: model.annualInflationRate, range: 0 ... 0.10, step: 0.001)
        slider("Contribution rises yearly", value: model.annualContributionGrowthRate, range: 0 ... 0.10, step: 0.005)

        Toggle("Show in today's money", isOn: model.showInTodaysMoney)
      }
    }
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
        Text(value.wrappedValue, format: .percent.precision(.fractionLength(1)))
          .typography(.numeric)
      }
      // Recomputing on every tick is fine: the projection is at most 1200 iterations of
      // arithmetic on device, so there is no round trip and no debounce to get wrong.
      Slider(value: value, in: range, step: step)
        .onChange(of: value.wrappedValue) { _, _ in model.recompute() }
    }
  }

  @ViewBuilder private var sensitivity: some View {
    if model.sensitivity.isEmpty == false {
      GlassCard {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
          Text("If the return is different")
            .typography(.small, weight: .semibold)

          ForEach(model.sensitivity) { point in
            HStack {
              Text(point.annualReturnRate, format: .percent.precision(.fractionLength(1)))
                .typography(.numeric)
              if abs(point.annualReturnRate - model.annualReturnRate) < 0.0001 {
                Text("your assumption")
                  .typography(.nano)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Text(point.endingValueNominal, format: .currency(code: model.currency).precision(.fractionLength(0)))
                .typography(.numeric)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  /// Not decoration. A projection that hides its rate is a number generator.
  private var assumptions: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
        Text("What this assumes")
          .typography(.small, weight: .semibold)
        Text("Returns are steady at \(model.annualReturnRate.formatted(.percent.precision(.fractionLength(1)))) a year, compounded monthly. Real markets are not steady.")
          .typography(.nano)
          .foregroundStyle(.secondary)
        Text("Contributions are made at the end of each month.")
          .typography(.nano)
          .foregroundStyle(.secondary)
        Text("Projections, not advice.")
          .typography(.nano)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
