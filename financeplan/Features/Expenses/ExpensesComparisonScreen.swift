import Charts
import SwiftUI
import StockPlanShared

struct ExpensesComparisonScreen: View {
  @StateObject private var reportsViewModel = ReportsViewModel()
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    NavigationStack {
      ZStack {
        MeshGradientBackground()
          .ignoresSafeArea()

        ScrollView {
          VStack(spacing: 24) {
            if reportsViewModel.isLoading && reportsViewModel.portfolioStatistics == nil && reportsViewModel.latestMonthSummary == nil {
              ProgressView()
                .padding(.top, 40)
            } else {
              // 1. Net Worth Snapshot
              NetWorthHeroCard(stats: reportsViewModel.portfolioStatistics)

              // 2. Portfolio Performance Breakdown
              PerformanceBreakdownCard(stats: reportsViewModel.portfolioStatistics)

              // 3. Personal Spending Analysis
              SpendingInsightsSection(
                monthSummary: reportsViewModel.latestMonthSummary,
                pillarSummaries: reportsViewModel.latestPillarSummaries,
                partnerName: reportsViewModel.partnerDisplayName
              )

              // 4. Household Comparison
              HouseholdSplitComparisonCard(
                summaries: reportsViewModel.monthlySummaries,
                partnerName: reportsViewModel.partnerDisplayName
              )

              // 5. Budget Tracking
              BudgetTrackingCard(
                summary: reportsViewModel.latestMonthSummary,
                partnerName: reportsViewModel.partnerDisplayName
              )

              // 6. Portfolio Allocation
              AllocationInsightsSection(stats: reportsViewModel.portfolioStatistics)

              // 7. Savings Rate
              SavingsRateCard(summary: reportsViewModel.latestMonthSummary)

              // 8. Monthly Cash Flow
              CashFlowAnalysisCard(points: reportsViewModel.cashFlow)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 20)
        }
      }
      .navigationTitle("Reports")
      .navigationBarTitleDisplayMode(.large)
      .refreshable {
        await reportsViewModel.load(force: true)
      }
      .task {
        await reportsViewModel.load()
      }
    }
  }
}

// MARK: - Net Worth Hero

private struct NetWorthHeroCard: View {
  let stats: ImportedStocksStatisticsDTO?
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GlassCard(cornerRadius: 24) {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("TOTAL NET WORTH")
              .font(.system(size: 10, weight: .bold))
              .tracking(1.5)
              .foregroundStyle(AppTheme.Colors.secondaryTint(for: colorScheme))

            Text((stats?.totalMarketValue ?? 0).formatted(.currency(code: "USD")))
              .font(.system(size: 36, weight: .bold, design: .rounded))
          }
          Spacer()
          Image(systemName: "dollarsign.circle.fill")
            .font(.title)
            .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
        }

        Divider().opacity(0.1)

        HStack(spacing: 20) {
          VStack(alignment: .leading, spacing: 4) {
            Text("UNREALIZED P&L")
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(.secondary)
            Text((stats?.totalUnrealizedPnl ?? 0).formatted(.currency(code: "USD")))
              .font(.headline)
              .foregroundStyle((stats?.totalUnrealizedPnl ?? 0) >= 0 ? .green : .red)
          }

          VStack(alignment: .leading, spacing: 4) {
            Text("POSITIONS")
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(.secondary)
            Text("\(stats?.totalPositions ?? 0)")
              .font(.headline)
          }
        }
      }
      .padding(20)
    }
  }
}

// MARK: - Spending Insights

private struct SpendingInsightsSection: View {
  let monthSummary: BudgetMonthSummary?
  let pillarSummaries: [PillarPlanningSummaryResponse]
  let partnerName: String
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Household Spending")
        .font(.title3.bold())

      if let latest = monthSummary, !pillarSummaries.isEmpty {
        GlassCard(cornerRadius: 20) {
          VStack(alignment: .leading, spacing: 16) {
            HStack {
              Text("LATEST MONTH BREAKDOWN")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
              Spacer()
              Text(latest.longLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Chart {
              ForEach(pillarSummaries.sorted(by: { $0.actualAmount > $1.actualAmount }), id: \.pillar) { summary in
                if #available(iOS 17.0, *) {
                  SectorMark(
                    angle: .value("Amount", summary.actualAmount),
                    angularInset: 1
                  )
                  .foregroundStyle(summary.pillar.color(for: colorScheme))
                  .annotation(position: .overlay) {
                      let total = latest.actual
                      let percent = total > 0 ? (summary.actualAmount / total) * 100 : 0
                      if percent > 5 {
                          VStack {
                              Text(summary.pillar.title)
                                  .font(.system(size: 10, weight: .bold))
                              Text("\(Int(percent))%")
                                  .font(.system(size: 10))
                          }
                          .foregroundStyle(.white)
                          .padding(4)
                          .background(Color.black.opacity(0.3).cornerRadius(4))
                      }
                  }
                }
              }
            }
            .frame(height: 220)

            VStack(spacing: 16) {
              HStack(spacing: 12) {
                personMetric(title: "Total", value: latest.actual)
                personMetric(title: "Me", value: latest.myActual)
                personMetric(title: partnerName, value: latest.partnerActual)
              }

              Text("Top Spending Categories")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

              ForEach(pillarSummaries.sorted(by: { $0.actualAmount > $1.actualAmount }), id: \.pillar) { summary in
                let percentage = summary.plannedAmount > 0 ? (summary.actualAmount / summary.plannedAmount) * 100 : 0

                HStack(spacing: 16) {
                  Circle()
                    .fill(summary.pillar.color(for: colorScheme).opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: icon(for: summary.pillar))
                            .foregroundStyle(summary.pillar.color(for: colorScheme))
                    }

                  VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(summary.pillar.title)
                          .font(.subheadline.bold())
                        Spacer()
                        Text("\(Int(percentage))% of Budget")
                          .font(.caption)
                          .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(summary.actualAmount.formatted(.currency(code: "USD")))
                          .font(.subheadline)
                          .foregroundStyle(.secondary)

                        Spacer()

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.05))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(summary.pillar.color(for: colorScheme))
                                    .frame(width: geo.size.width * CGFloat(min(percentage / 100, 1.0)), height: 6)
                            }
                        }
                        .frame(width: 100, height: 6)
                    }
                  }
                }
              }
            }
          }
          .padding(20)
        }
      } else {
        ResearchPlaceholderCard(title: "No spending data", bodyText: "Start logging your expenses to see detailed reports.")
      }
    }
  }

  private func icon(for pillar: BudgetPillar) -> String {
      switch pillar {
      case .fundamentals: return "house.fill"
      case .futureYou: return "leaf.fill"
      case .fun: return "popcorn.fill"
      }
  }

  @ViewBuilder
  private func personMetric(title: String, value: Double) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value.formatted(.currency(code: "USD")))
        .font(.subheadline.bold())
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

private struct HouseholdSplitComparisonCard: View {
  let summaries: [BudgetMonthSummary]
  let partnerName: String
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Monthly Split Comparison")
        .font(.title3.bold())

      GlassCard(cornerRadius: 20) {
        if summaries.isEmpty {
          ResearchPlaceholderCard(title: "No household data", bodyText: "Log shared expenses to compare your share with \(partnerName).")
        } else {
          VStack(alignment: .leading, spacing: 16) {
            Text("TOTAL VS ME VS \(partnerName.uppercased())")
              .font(.system(size: 10, weight: .bold))
              .tracking(1.2)
              .foregroundStyle(.secondary)

            Chart {
              ForEach(summaries.prefix(6).reversed()) { summary in
                BarMark(
                  x: .value("Month", summary.shortLabel),
                  y: .value("Total", summary.actual)
                )
                .foregroundStyle(AppTheme.Colors.secondaryTint(for: colorScheme).opacity(0.35))
                .position(by: .value("Series", "Total"))

                BarMark(
                  x: .value("Month", summary.shortLabel),
                  y: .value("Me", summary.myActual)
                )
                .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                .position(by: .value("Series", "Me"))

                BarMark(
                  x: .value("Month", summary.shortLabel),
                  y: .value("Partner", summary.partnerActual)
                )
                .foregroundStyle(.green.opacity(0.85))
                .position(by: .value("Series", partnerName))
              }
            }
            .frame(height: 220)

            HStack(spacing: 20) {
              legend(title: "Total", color: AppTheme.Colors.secondaryTint(for: colorScheme))
              legend(title: "Me", color: AppTheme.Colors.tint(for: colorScheme))
              legend(title: partnerName, color: .green)
            }
            .font(.caption2.bold())
          }
          .padding(20)
        }
      }
    }
  }

  private func legend(title: String, color: Color) -> some View {
    Label(title, systemImage: "square.fill")
      .foregroundStyle(color)
  }
}

// MARK: - Allocation Insights

private struct AllocationInsightsSection: View {
  let stats: ImportedStocksStatisticsDTO?
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Portfolio Allocation")
        .font(.title3.bold())

      GlassCard(cornerRadius: 20) {
        VStack(alignment: .leading, spacing: 20) {
          Text("SECTOR WEIGHTING")
            .font(.system(size: 10, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(.secondary)

          if let sectors = stats?.sectorAllocations, !sectors.isEmpty {
            ZStack {
                Chart(sectors, id: \.sector) { item in
                  if #available(iOS 17.0, *) {
                      SectorMark(
                        angle: .value("Weight", item.weightPercent),
                        innerRadius: .ratio(0.6),
                        angularInset: 1
                      )
                      .foregroundStyle(color(for: item.sector, colorScheme: colorScheme))
                      .annotation(position: .overlay) {
                          if item.weightPercent > 5 {
                              Text("\(Int(item.weightPercent))%")
                                  .font(.system(size: 10, weight: .bold))
                                  .foregroundStyle(.white)
                          }
                      }
                  } else {
                      BarMark(
                        x: .value("Weight", item.weightPercent),
                        y: .value("Sector", item.sector)
                      )
                      .foregroundStyle(color(for: item.sector, colorScheme: colorScheme))
                  }
                }
                .frame(height: 220)

                if #available(iOS 17.0, *) {
                    VStack {
                        Text("Total Value")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text((stats?.totalMarketValue ?? 0).formatted(.currency(code: "USD")))
                            .font(.headline.bold())
                    }
                }
            }

            VStack(spacing: 16) {
              Text("Sector Weighting")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

              ForEach(sectors.sorted(by: { $0.weightPercent > $1.weightPercent }), id: \.sector) { item in
                HStack(spacing: 16) {
                  RoundedRectangle(cornerRadius: 8)
                    .fill(color(for: item.sector, colorScheme: colorScheme).opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: icon(for: item.sector))
                            .foregroundStyle(color(for: item.sector, colorScheme: colorScheme))
                    }

                  Text(item.sector)
                    .font(.subheadline)

                  Spacer()

                  let value = (stats?.totalMarketValue ?? 0) * (item.weightPercent / 100.0)
                  Text("\(Int(item.weightPercent))% | \(value.formatted(.currency(code: "USD")))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
              }
            }
          } else {
            Text("No sector data available")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .padding(20)
      }
    }
  }

  private func icon(for sector: String) -> String {
      switch sector.lowercased() {
      case "technology": return "cpu"
      case "finance", "financial Services": return "building.columns.fill"
      case "energy": return "bolt.fill"
      case "healthcare": return "heart.text.square.fill"
      case "consumer cyclical": return "cart.fill"
      case "communication services": return "network"
      default: return "circle.grid.2x2.fill"
      }
  }

  private func color(for sector: String, colorScheme: ColorScheme) -> Color {
      switch sector.lowercased() {
      case "technology": return .blue
      case "finance", "financial Services": return .green
      case "energy": return .orange
      case "healthcare": return .purple
      case "consumer cyclical": return .pink
      case "communication services": return .teal
      default: return .gray
      }
  }
}

// MARK: - Performance Breakdown

private struct PerformanceBreakdownCard: View {
  let stats: ImportedStocksStatisticsDTO?
  @Environment(\.colorScheme) private var colorScheme

  private var winnersValue: Double {
    stats?.stockSummaries.filter { $0.unrealizedPnl > 0 }.reduce(0) { $0 + $1.unrealizedPnl } ?? 0
  }

  private var losersValue: Double {
    abs(stats?.stockSummaries.filter { $0.unrealizedPnl < 0 }.reduce(0) { $0 + $1.unrealizedPnl } ?? 0)
  }

  private var winnersCount: Int {
    stats?.stockSummaries.filter { $0.unrealizedPnl > 0 }.count ?? 0
  }

  private var losersCount: Int {
    stats?.stockSummaries.filter { $0.unrealizedPnl < 0 }.count ?? 0
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Portfolio Performance")
        .font(.title3.bold())

      GlassCard(cornerRadius: 20) {
        VStack(alignment: .leading, spacing: 20) {
          HStack {
            Text("WINNERS VS LOSERS")
              .font(.system(size: 10, weight: .bold))
              .tracking(1.2)
              .foregroundStyle(.secondary)
            Spacer()
            Text("\(winnersCount + losersCount) Positions")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }

          if winnersValue + losersValue > 0 {
            Chart {
              if #available(iOS 17.0, *) {
                SectorMark(
                  angle: .value("Amount", winnersValue),
                  innerRadius: .ratio(0.6),
                  angularInset: 2
                )
                .foregroundStyle(.green.gradient)
                .cornerRadius(4)

                SectorMark(
                  angle: .value("Amount", losersValue),
                  innerRadius: .ratio(0.6),
                  angularInset: 2
                )
                .foregroundStyle(.red.gradient)
                .cornerRadius(4)
              }
            }
            .frame(height: 180)
            .overlay {
              VStack(spacing: 4) {
                Text("Net P&L")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                Text((stats?.totalUnrealizedPnl ?? 0).formatted(.currency(code: "USD")))
                  .font(.title3.bold())
                  .foregroundStyle((stats?.totalUnrealizedPnl ?? 0) >= 0 ? .green : .red)
              }
            }

            HStack(spacing: 40) {
              VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                  Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                  Text("Winners")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Text(winnersValue.formatted(.currency(code: "USD")))
                  .font(.headline.bold())
                  .foregroundStyle(.green)
                Text("\(winnersCount) positions")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }

              VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                  Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                  Text("Losers")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Text(losersValue.formatted(.currency(code: "USD")))
                  .font(.headline.bold())
                  .foregroundStyle(.red)
                Text("\(losersCount) positions")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
            }
          } else {
            Text("No performance data available")
              .font(.caption)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .center)
              .padding(.vertical, 40)
          }
        }
        .padding(20)
      }
    }
  }
}

// MARK: - Budget Tracking

private struct BudgetTrackingCard: View {
  let summary: BudgetMonthSummary?
  let partnerName: String
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Household Budget Tracking")
        .font(.title3.bold())

      if let latest = summary {
        GlassCard(cornerRadius: 20) {
          VStack(alignment: .leading, spacing: 20) {
            HStack {
              Text("PLANNED VS ACTUAL")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
              Spacer()
              Text(latest.longLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Chart {
              if #available(iOS 17.0, *) {
                SectorMark(
                  angle: .value("Amount", latest.actual),
                  innerRadius: .ratio(0.6),
                  angularInset: 2
                )
                .foregroundStyle(latest.actual > latest.planned ? Color.red.gradient : AppTheme.Colors.tint(for: colorScheme).gradient)
                .cornerRadius(4)

                if latest.planned > latest.actual {
                  SectorMark(
                    angle: .value("Amount", latest.planned - latest.actual),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                  )
                  .foregroundStyle(Color.gray.opacity(0.3))
                  .cornerRadius(4)
                }
              }
            }
            .frame(height: 180)
            .overlay {
              VStack(spacing: 4) {
                Text("Spent")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                Text(latest.actual.formatted(.currency(code: "USD")))
                  .font(.title3.bold())
                let percentage = latest.planned > 0 ? (latest.actual / latest.planned) * 100 : 0
                Text("\(Int(percentage))% of budget")
                  .font(.caption2)
                  .foregroundStyle(latest.actual > latest.planned ? .red : .secondary)
              }
            }

            HStack(spacing: 40) {
              VStack(alignment: .leading, spacing: 4) {
                Text("PLANNED")
                  .font(.system(size: 9, weight: .bold))
                  .foregroundStyle(.secondary)
                Text(latest.planned.formatted(.currency(code: "USD")))
                  .font(.headline.bold())
              }

              VStack(alignment: .leading, spacing: 4) {
                Text("ACTUAL")
                  .font(.system(size: 9, weight: .bold))
                  .foregroundStyle(.secondary)
                Text(latest.actual.formatted(.currency(code: "USD")))
                  .font(.headline.bold())
                  .foregroundStyle(latest.actual > latest.planned ? .red : .primary)
              }

              VStack(alignment: .leading, spacing: 4) {
                Text("REMAINING")
                  .font(.system(size: 9, weight: .bold))
                  .foregroundStyle(.secondary)
                let remaining = latest.planned - latest.actual
                Text(remaining.formatted(.currency(code: "USD")))
                  .font(.headline.bold())
                  .foregroundStyle(remaining >= 0 ? .green : .red)
              }
            }

            Divider().opacity(0.1)

            HStack(spacing: 20) {
              personColumn(title: "Me", planned: latest.myPlanned, actual: latest.myActual)
              personColumn(title: partnerName, planned: latest.partnerPlanned, actual: latest.partnerActual)
            }
          }
          .padding(20)
        }
      } else {
        ResearchPlaceholderCard(title: "No budget data", bodyText: "Create a budget snapshot to track your spending.")
      }
    }
  }

  private func personColumn(title: String, planned: Double, actual: Double) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title.uppercased())
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(.secondary)
      Text("Plan \(planned.formatted(.currency(code: "USD")))")
        .font(.caption)
      Text("Actual \(actual.formatted(.currency(code: "USD")))")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Savings Rate

private struct SavingsRateCard: View {
  let summary: BudgetMonthSummary?
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Savings Rate")
        .font(.title3.bold())

      if let latest = summary {
        let savingsAmount = latest.salary - latest.actual
        let savingsRate = latest.salary > 0 ? (savingsAmount / latest.salary) * 100 : 0
        let spendingRate = latest.salary > 0 ? (latest.actual / latest.salary) * 100 : 0

        GlassCard(cornerRadius: 20) {
          VStack(alignment: .leading, spacing: 20) {
            HStack {
              Text("INCOME ALLOCATION")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
              Spacer()
              Text(latest.longLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Chart {
              if #available(iOS 17.0, *) {
                SectorMark(
                  angle: .value("Amount", savingsAmount > 0 ? savingsAmount : 0),
                  innerRadius: .ratio(0.6),
                  angularInset: 2
                )
                .foregroundStyle(.green.gradient)
                .cornerRadius(4)

                SectorMark(
                  angle: .value("Amount", latest.actual),
                  innerRadius: .ratio(0.6),
                  angularInset: 2
                )
                .foregroundStyle(AppTheme.Colors.secondaryTint(for: colorScheme).gradient)
                .cornerRadius(4)
              }
            }
            .frame(height: 180)
            .overlay {
              VStack(spacing: 4) {
                Text("Savings Rate")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                Text("\(Int(savingsRate))%")
                  .font(.system(size: 32, weight: .bold, design: .rounded))
                  .foregroundStyle(.green)
              }
            }

            VStack(spacing: 12) {
              HStack {
                HStack(spacing: 8) {
                  Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                  Text("Saved")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                  Text(savingsAmount.formatted(.currency(code: "USD")))
                    .font(.headline.bold())
                    .foregroundStyle(.green)
                  Text("\(Int(savingsRate))% of income")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
              }

              HStack {
                HStack(spacing: 8) {
                  Circle()
                    .fill(AppTheme.Colors.secondaryTint(for: colorScheme))
                    .frame(width: 8, height: 8)
                  Text("Spent")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                  Text(latest.actual.formatted(.currency(code: "USD")))
                    .font(.headline.bold())
                  Text("\(Int(spendingRate))% of income")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
              }

              Divider().opacity(0.1)

              HStack {
                Text("Total Income")
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
                Spacer()
                Text(latest.salary.formatted(.currency(code: "USD")))
                  .font(.headline.bold())
              }
            }
          }
          .padding(20)
        }
      } else {
        ResearchPlaceholderCard(title: "No income data", bodyText: "Add your salary to budget snapshots to track savings rate.")
      }
    }
  }
}

// MARK: - Cash Flow Analysis

private struct CashFlowAnalysisCard: View {
  let points: [ReportsCashFlowPointResponse]
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Cash Flow History")
        .font(.title3.bold())

      GlassCard(cornerRadius: 20) {
        VStack(alignment: .leading, spacing: 16) {
          if points.isEmpty {
            ResearchPlaceholderCard(title: "No cash flow data", bodyText: "Add salary and expense data to see monthly cash flow.")
          } else {
            Chart {
              ForEach(points) { point in
                BarMark(
                  x: .value("Month", monthLabel(for: point.monthStart)),
                  y: .value("Amount", point.income)
                )
                .foregroundStyle(.green.opacity(0.8))
                .position(by: .value("Type", "Income"))

                BarMark(
                  x: .value("Month", monthLabel(for: point.monthStart)),
                  y: .value("Amount", point.expenses)
                )
                .foregroundStyle(.red.opacity(0.8))
                .position(by: .value("Type", "Expenses"))
              }
            }
            .frame(height: 200)

            HStack(spacing: 20) {
              Label("Income", systemImage: "square.fill").foregroundStyle(.green)
              Label("Expenses", systemImage: "square.fill").foregroundStyle(.red)
            }
            .font(.caption2.bold())
          }
        }
        .padding(20)
      }
    }
  }

  private func monthLabel(for monthStart: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    guard let date = formatter.date(from: monthStart) else { return monthStart }
    return date.formatted(.dateTime.month(.abbreviated))
  }
}
