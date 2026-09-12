import Charts
import SwiftUI

/// Price a portfolio before you own it: pick the positions, set the weights, and
/// see what building it would cost.
struct PortfolioSimulatorScreen: View {
  @State private var viewModel = PortfolioSimulatorViewModel()
  @State private var savedConfirmation: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
        positionsCard
        if let result = viewModel.result {
          allocationCard(result)
          resultCard(result)
        }
        if let errorMessage = viewModel.errorMessage {
          errorCard(errorMessage)
        }
      }
      .padding(AppTheme.Spacing.lg)
      .maxContentWidth(regularSizeClass: ContentWidth.dense)
    }
    .vigilScreenBackground()
    .vigilNavigationTitle("Simulator")
    .task { await viewModel.loadPortfolios() }
  }

  // MARK: - Input

  private var positionsCard: some View {
    ChartCard(
      title: "Positions",
      subtitle: "Weights need not add up to 100% — whatever is left over is held as cash."
    ) {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
        LabeledContent("Name") {
          TextField("Name", text: $viewModel.name)
            .multilineTextAlignment(.trailing)
        }

        LabeledContent("Capital") {
          TextField("Capital", value: $viewModel.targetCapital, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
        }

        if !viewModel.portfolios.isEmpty {
          Picker("Compare against", selection: $viewModel.sourcePortfolioId) {
            Text("Start from scratch").tag(String?.none)
            ForEach(viewModel.portfolios) { portfolio in
              Text(portfolio.name).tag(String?.some(portfolio.id))
            }
          }
        }

        Divider()

        ForEach($viewModel.legs) { $leg in
          HStack(spacing: AppTheme.Spacing.sm) {
            TextField("Ticker", text: $leg.symbol)
              .textInputAutocapitalization(.characters)
              .autocorrectionDisabled()
            TextField("Weight", value: $leg.weightPercent, format: .number)
              .keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing)
              .frame(width: 72)
            Text("%")
              .typography(.footnote)
              .foregroundStyle(AppTheme.Colors.secondaryText)
          }
        }
        .onDelete { viewModel.removeLeg(at: $0) }

        HStack {
          Button("Add position") { viewModel.addLeg() }
          Spacer()
          Button("Equal weight") { viewModel.equalWeight() }
        }
        .typography(.footnote)

        allocationSummary

        Toggle("Allow fractional shares", isOn: $viewModel.fractionalSharesEnabled)
          .typography(.footnote)

        Button {
          Task { await viewModel.simulate() }
        } label: {
          if viewModel.isRunning {
            ProgressView()
          } else {
            Text("Simulate")
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canSimulate)

        Button("Save simulation") {
          Task {
            if let saved = await viewModel.save() {
              savedConfirmation = saved.name
            }
          }
        }
        .typography(.footnote)
        .disabled(!viewModel.canSimulate)

        if let savedConfirmation {
          Text("Saved “\(savedConfirmation)”.")
            .typography(.footnote)
            .foregroundStyle(AppTheme.Colors.success)
        }
      }
    }
  }

  private var allocationSummary: some View {
    Group {
      if viewModel.isOverAllocated {
        Text(
          "Weights total \(PortfolioSimulatorViewModel.percent(viewModel.claimedBasisPoints)) — more than the whole portfolio."
        )
        .foregroundStyle(AppTheme.Colors.danger)
      } else {
        Text(
          "\(PortfolioSimulatorViewModel.percent(viewModel.claimedBasisPoints)) allocated, \(PortfolioSimulatorViewModel.percent(viewModel.cashBasisPoints)) held as cash."
        )
        .foregroundStyle(AppTheme.Colors.secondaryText)
      }
    }
    .typography(.footnote)
  }

  // MARK: - Output

  private func allocationCard(_ result: PortfolioSimulationResult) -> some View {
    ChartCard(title: "Allocation") {
      Chart(donutSlices(for: result), id: \.label) { slice in
        SectorMark(
          angle: .value("Weight", slice.basisPoints),
          innerRadius: .ratio(0.62),
          angularInset: 1.5
        )
        .cornerRadius(4)
        .foregroundStyle(by: .value("Position", slice.label))
      }
      .frame(height: 240)
      .overlay {
        VStack(spacing: 2) {
          Text(PortfolioSimulatorViewModel.money(result.totalCashNeeded, currency: result.simulation.baseCurrency))
            .typography(.metricNumber, weight: .bold)
          Text("to build")
            .typography(.footnote)
            .foregroundStyle(AppTheme.Colors.secondaryText)
        }
      }
      .appAnimation(AppMotion.dataReveal, value: result.generatedAt)
    }
  }

  private func resultCard(_ result: PortfolioSimulationResult) -> some View {
    ChartCard(title: "What it would cost") {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
        MetricRow(
          title: "Cash needed",
          value: PortfolioSimulatorViewModel.money(result.totalCashNeeded, currency: result.simulation.baseCurrency)
        )
        MetricRow(
          title: "Left over",
          value: PortfolioSimulatorViewModel.money(result.leftoverCash, currency: result.simulation.baseCurrency)
        )
        MetricRow(
          title: "Cash weight",
          value: PortfolioSimulatorViewModel.percent(result.cashBasisPoints)
        )

        if viewModel.showsRoundingNote {
          Text("Whole-share rounding leaves that unspent. Allow fractional shares to deploy it.")
            .typography(.footnote)
            .foregroundStyle(AppTheme.Colors.secondaryText)
        }

        ForEach(result.warnings) { warning in
          Text(warning.message)
            .typography(.footnote)
            .foregroundStyle(AppTheme.Colors.warning)
        }

        if !result.simulation.trades.isEmpty {
          Divider()
          Text("Trades")
            .typography(.footnote, weight: .semibold)
          ForEach(result.simulation.trades) { trade in
            HStack {
              Text(trade.symbol)
                .typography(.footnote, weight: .semibold)
              Text(trade.isBuy ? "Buy" : "Sell")
                .typography(.footnote)
                .foregroundStyle(trade.isBuy ? AppTheme.Colors.success : AppTheme.Colors.danger)
              Spacer()
              Text(PortfolioSimulatorViewModel.quantity(trade.quantity))
                .typography(.numericSmall)
              Text(PortfolioSimulatorViewModel.money(trade.notional, currency: result.simulation.baseCurrency))
                .typography(.numericSmall)
                .foregroundStyle(AppTheme.Colors.secondaryText)
            }
          }
        }

        if !result.diff.isEmpty {
          Divider()
          Text("Against your current portfolio")
            .typography(.footnote, weight: .semibold)
          ForEach(result.diff) { row in
            HStack {
              Text(row.symbol)
                .typography(.footnote, weight: .semibold)
              Spacer()
              Text(PortfolioSimulatorViewModel.percent(row.currentBasisPoints))
                .typography(.numericSmall)
                .foregroundStyle(AppTheme.Colors.secondaryText)
              Image(systemName: "arrow.right")
                .typography(.nano)
                .foregroundStyle(AppTheme.Colors.tertiaryText)
              Text(PortfolioSimulatorViewModel.percent(row.targetBasisPoints))
                .typography(.numericSmall)
                .foregroundStyle(
                  row.deltaBasisPoints > 0
                    ? AppTheme.Colors.success
                    : (row.deltaBasisPoints < 0 ? AppTheme.Colors.danger : AppTheme.Colors.foreground)
                )
            }
          }
        }
      }
    }
  }

  private func errorCard(_ message: String) -> some View {
    GlassCard {
      Text(message)
        .typography(.footnote)
        .foregroundStyle(AppTheme.Colors.danger)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private struct DonutSlice {
    let label: String
    let basisPoints: Int
  }

  /// Cash is a real slice, so it is drawn rather than left as an invisible gap.
  private func donutSlices(for result: PortfolioSimulationResult) -> [DonutSlice] {
    var slices = viewModel.legs
      .filter(\.isFilled)
      .map { DonutSlice(label: $0.symbol.uppercased(), basisPoints: $0.basisPoints) }
      .sorted { $0.basisPoints > $1.basisPoints }
    if result.cashBasisPoints > 0 {
      slices.append(DonutSlice(label: "Cash", basisPoints: result.cashBasisPoints))
    }
    return slices
  }
}
