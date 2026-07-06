import Charts
import SwiftUI
import StockPlanShared
import Factory

struct ExpensesComparisonScreen: View {
  @State private var reportsViewModel = ReportsViewModel()
  @State private var dashboardPrefs = ReportsDashboardPreferences()
  @Environment(\.colorScheme) private var colorScheme
  @InjectedObservable(\Container.billingManager) private var billingManager
  @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.english.rawValue
  @State private var selectedTab: ReportTab = .overview
  @State private var showingCustomize = false

  private var appLanguage: AppLanguage {
    AppLanguage.from(appLanguageRawValue)
  }

  private var isShowingLoadingState: Bool {
    reportsViewModel.isLoading &&
      reportsViewModel.portfolioStatistics == nil &&
      reportsViewModel.latestMonthSummary == nil
  }

  private var loadErrorMessage: String? {
    guard reportsViewModel.monthlySummaries.isEmpty else { return nil }
    return reportsViewModel.errorMessage
  }

  private var shouldShowEmptyState: Bool {
    !reportsViewModel.isLoading && reportsViewModel.monthlySummaries.isEmpty
  }

  private var visibleCards: [ReportCard] {
    dashboardPrefs.visibleCards.filter { cardMatchesSelectedTab($0) }
  }

  enum ReportTab: String, CaseIterable {
    case overview = "Overview"
    case portfolio = "Portfolio"
    case spending = "Spending"
    case trends = "Trends"
    
    var title: String {
      switch self {
      case .overview: return String(localized: "Overview")
      case .portfolio: return String(localized: "Portfolio")
      case .spending: return String(localized: "Spending")
      case .trends: return String(localized: "Trends")
      }
    }

    var icon: String {
      switch self {
      case .overview: return "chart.bar.fill"
      case .portfolio: return "briefcase.fill"
      case .spending: return "creditcard.fill"
      case .trends: return "chart.line.uptrend.xyaxis"
      }
    }
  }

  var body: some View {
    ProGateView(billingManager: billingManager) {
      NavigationStack {
        ZStack {
          MeshGradientBackground()
            .ignoresSafeArea()

          VStack(spacing: 0) {
            tabPicker

            ScrollView {
              ReportContentView(
                isShowingLoadingState: isShowingLoadingState,
                loadErrorMessage: loadErrorMessage,
                shouldShowEmptyState: shouldShowEmptyState,
                cards: visibleCards,
                onRetry: retryLoad,
                cardContent: cardView(for:)
              )
              .padding(.horizontal, 16)
              .padding(.vertical, 20)
              .accessibilityIdentifier("reports.scrollContent")
              // Center the reports column on iPad instead of stretching edge-to-edge (Guideline 4).
              .maxContentWidth(regularSizeClass: ContentWidth.dense)
            }
          }
        }
        .navigationTitle(LocalizedStringKey("Reports"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              showingCustomize = true
            } label: {
              Image(systemName: "slider.horizontal.3")
            }
.buttonStyle(.borderedProminent)
            .accessibilityIdentifier("reports.customizeButton")
          }
        }
        .refreshable {
          await reloadReports(force: true)
        }
        .task {
          await initialLoad()
        }
        .onReceive(NotificationCenter.default.publisher(for: .budgetPlannerDataDidChange)) { _ in
          Task { await reloadReports(force: true) }
        }
        .sheet(isPresented: $showingCustomize) {
          CustomizeDashboardSheet(preferences: dashboardPrefs)
        }
      }
    }
  }

  private var tabPicker: some View {
    Picker("Report Section", selection: $selectedTab.animation(.easeInOut(duration: 0.3))) {
      ForEach(ReportTab.allCases, id: \.self) { tab in
        Label(tab.title, systemImage: tab.icon).tag(tab)
      }
    }
    .pickerStyle(.segmented)
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  @ViewBuilder
  private func cardView(for card: ReportCard) -> some View {
    switch card {
    case .netWorth:
      NetWorthHeroCard(stats: reportsViewModel.portfolioStatistics)
    case .quickStats:
      if let summary = reportsViewModel.latestMonthSummary {
        QuickStatsCard(summary: summary, stats: reportsViewModel.portfolioStatistics)
      }
    case .insights:
      SmartInsightsCard(summary: reportsViewModel.latestMonthSummary, stats: reportsViewModel.portfolioStatistics)
    case .performance:
      PerformanceBreakdownCard(stats: reportsViewModel.portfolioStatistics)
    case .allocation:
      AllocationInsightsSection(stats: reportsViewModel.portfolioStatistics)
    case .spending:
      SpendingInsightsSection(
        monthSummary: reportsViewModel.latestMonthSummary,
        pillarSummaries: reportsViewModel.latestPillarSummaries,
        partnerName: reportsViewModel.partnerDisplayName
      )
    case .budget:
      BudgetTrackingCard(
        summary: reportsViewModel.latestMonthSummary,
        partnerName: reportsViewModel.partnerDisplayName
      )
    case .savings:
      SavingsRateCard(summary: reportsViewModel.latestMonthSummary)
    case .household:
      HouseholdSplitComparisonCard(
        summaries: reportsViewModel.monthlySummaries,
        partnerName: reportsViewModel.partnerDisplayName
      )
    case .cashFlow:
      CashFlowAnalysisCard(points: reportsViewModel.cashFlow)
    }
  }

  private func initialLoad() async {
    await reloadReports(force: true)
  }

  private func reloadReports(force: Bool = false) async {
    await reportsViewModel.load(force: force)
  }

  private func retryLoad() {
    Task { await reloadReports(force: true) }
  }

  private func cardMatchesSelectedTab(_ card: ReportCard) -> Bool {
    switch selectedTab {
    case .overview:
      return isOverviewCard(card)
    case .portfolio:
      return isPortfolioCard(card)
    case .spending:
      return isSpendingCard(card)
    case .trends:
      return isTrendsCard(card)
    }
  }

  private func isOverviewCard(_ card: ReportCard) -> Bool {
    [.netWorth, .quickStats, .insights].contains(card)
  }
  
  private func isPortfolioCard(_ card: ReportCard) -> Bool {
    [.netWorth, .performance, .allocation].contains(card)
  }
  
  private func isSpendingCard(_ card: ReportCard) -> Bool {
    [.spending, .budget, .savings].contains(card)
  }
  
  private func isTrendsCard(_ card: ReportCard) -> Bool {
    [.household, .cashFlow].contains(card)
  }
}

private struct ReportCardsSection<Content: View>: View {
  let cards: [ReportCard]
  let content: (ReportCard) -> Content

  var body: some View {
    ForEach(cards) { card in
      content(card)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
  }
}

private struct ReportContentView<CardContent: View>: View {
  let isShowingLoadingState: Bool
  let loadErrorMessage: String?
  let shouldShowEmptyState: Bool
  let cards: [ReportCard]
  let onRetry: () -> Void
  let cardContent: (ReportCard) -> CardContent

  var body: some View {
    VStack(spacing: 24) {
      if isShowingLoadingState {
        ProgressView()
          .padding(.top, 40)
      } else if let loadErrorMessage {
        ErrorRetryView(message: loadErrorMessage, onRetry: onRetry)
      } else if shouldShowEmptyState {
        EmptyStateView(
          icon: "chart.pie",
          title: "No reports yet",
          message: "Reports appear once you have expenses recorded."
        )
      } else {
        ReportCardsSection(cards: cards, content: cardContent)
      }
    }
  }
}

// MARK: - Customize Dashboard Sheet

private struct IdentifiedImage: Identifiable {
  let id = UUID()
  let uiImage: UIImage
}

private struct ShareableChartButton<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content
  @State private var exportedImage: IdentifiedImage?

  var body: some View {
    Button("Share chart", systemImage: "square.and.arrow.up") {
      exportChart()
    }
    .labelStyle(.iconOnly)
    .font(.subheadline)
    .sheet(item: $exportedImage) { identified in
      ShareSheet(items: [identified.uiImage])
    }
  }

  @MainActor
  private func exportChart() {
    let exportView = VStack(spacing: 16) {
      Text(title)
        .font(.title2.bold())
        .frame(maxWidth: .infinity, alignment: .leading)
      content
    }
    .padding(24)
    .background(Color(uiColor: .systemBackground))

    if let image = ChartExporter.exportToImage(exportView, size: CGSize(width: 800, height: 600)) {
      exportedImage = IdentifiedImage(uiImage: image)
    }
  }
}

private struct CustomizeDashboardSheet: View {
  @Bindable var preferences: ReportsDashboardPreferences
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme
  
  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(preferences.cardOrder) { card in
            HStack(spacing: 12) {
              Image(systemName: card.icon)
                .foregroundStyle(preferences.hiddenCards.contains(card) ? Color.secondary : Color.blue)
                .frame(width: 24)
              
              Text(card.rawValue)
                .foregroundStyle(preferences.hiddenCards.contains(card) ? .secondary : .primary)
              
              Spacer()
              
              Button {
                withAnimation {
                  preferences.toggleCard(card)
                }
              } label: {
                Image(systemName: preferences.hiddenCards.contains(card) ? "eye.slash" : "eye")
                  .foregroundStyle(preferences.hiddenCards.contains(card) ? Color.secondary : Color.blue)
              }
.buttonStyle(.bordered)
            }
          }
          .onMove { source, destination in
            preferences.moveCard(from: source, to: destination)
          }
        } header: {
          Text("Drag to reorder, tap eye to show/hide")
        }
        
        Section {
          Button("Reset to Default") {
            withAnimation {
              preferences.resetToDefault()
            }
          }
          .foregroundStyle(.red)
        }
      }
      .navigationTitle("Customize Dashboard")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          EditButton()
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
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
              .typography(.nano, weight: .bold)
              .tracking(1.5)
              .foregroundStyle(AppTheme.Colors.secondaryTint(for: colorScheme))

            Text((stats?.totalMarketValue ?? 0).formatted(.currency(code: "USD")))
              .font(.largeTitle.bold()).fontDesign(.rounded)
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
              .typography(.nano, weight: .bold)
              .foregroundStyle(.secondary)
            Text((stats?.totalUnrealizedPnl ?? 0).formatted(.currency(code: "USD")))
              .font(.headline)
              .foregroundStyle((stats?.totalUnrealizedPnl ?? 0) >= 0 ? .green : .red)
          }

          VStack(alignment: .leading, spacing: 4) {
            Text("POSITIONS")
              .typography(.nano, weight: .bold)
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
  @State private var selectedPillar: BudgetPillar?
  @State private var showingPillarDetail = false

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Household Spending")
          .font(.title3.bold())
        Spacer()
        if let latest = monthSummary, !pillarSummaries.isEmpty {
          ShareableChartButton(title: "Household Spending - \(latest.longLabel)") {
            spendingChartContent(latest: latest)
          }
        }
      }

      if let latest = monthSummary, !pillarSummaries.isEmpty {
        GlassCard(cornerRadius: 20) {
          VStack(alignment: .leading, spacing: 16) {
            spendingChartContent(latest: latest)
          }
          .padding(20)
        }
        .sheet(isPresented: $showingPillarDetail) {
          if let pillar = selectedPillar,
             let summary = pillarSummaries.first(where: { $0.pillar == pillar }) {
            PillarDetailSheet(
              pillar: pillar,
              summary: summary,
              monthSummary: latest,
              partnerName: partnerName
            )
          }
        }
      } else {
        ResearchPlaceholderCard(title: "No spending data", bodyText: "Start logging your expenses to see detailed reports.")
      }
    }
  }
  
  @ViewBuilder
  private func spendingChartContent(latest: BudgetMonthSummary) -> some View {
    HStack {
      Text("LATEST MONTH BREAKDOWN")
        .typography(.nano, weight: .bold)
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
                          .typography(.nano, weight: .bold)
                      Text("\(Int(percent))%")
                          .typography(.nano)
                  }
                  .foregroundStyle(.white)
                  .padding(4)
                  .background(Color.black.opacity(0.3), in: .rect(cornerRadius: 4))
              }
          }
        }
      }
    }
    .frame(minHeight: 220)
    .accessibilityIdentifier("reports.spendingChart")

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

        Button {
          selectedPillar = summary.pillar
          showingPillarDetail = true
        } label: {
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
                    .foregroundStyle(.primary)
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

                  ProgressBar(
                      value: summary.actualAmount,
                      total: summary.plannedAmount > 0 ? summary.plannedAmount : summary.actualAmount,
                      color: summary.pillar.color(for: colorScheme),
                      height: 6,
                      showPattern: false
                  )
                  .frame(width: 100)
              }
            }
            
            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
.buttonStyle(.bordered)
      }
    }
  }

  private func icon(for pillar: BudgetPillar) -> String {
      if pillar == .fundamentals { return "house.fill" }
      if pillar == .futureYou { return "leaf.fill" }
      if pillar == .fun { return "popcorn.fill" }
      return "square.stack.3d.up.fill"
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
              .typography(.nano, weight: .bold)
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
            .frame(minHeight: 220)

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
            .typography(.nano, weight: .bold)
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
                                  .typography(.nano, weight: .bold)
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
                .frame(minHeight: 220)

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
              .frame(maxWidth: .infinity, minHeight: 220)
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
              .typography(.nano, weight: .bold)
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
                  outerRadius: .ratio(1.0),
                  angularInset: 2
                )
                .foregroundStyle(.green.gradient)

                SectorMark(
                  angle: .value("Amount", losersValue),
                  innerRadius: .ratio(0.6),
                  outerRadius: .ratio(1.0),
                  angularInset: 2
                )
                .foregroundStyle(.red.gradient)
              }
            }
            .frame(minHeight: 180)
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
              .frame(minHeight: 180)
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
                .typography(.nano, weight: .bold)
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
                  outerRadius: .ratio(1.0),
                  angularInset: 2
                )
                .foregroundStyle(latest.actual > latest.planned ? Color.red.gradient : AppTheme.Colors.tint(for: colorScheme).gradient)

                if latest.planned > latest.actual {
                  SectorMark(
                    angle: .value("Amount", latest.planned - latest.actual),
                    innerRadius: .ratio(0.6),
                    outerRadius: .ratio(1.0),
                    angularInset: 2
                  )
                  .foregroundStyle(Color.gray.opacity(0.3))
                }
              }
            }
            .frame(minHeight: 180)
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
                  .typography(.nano, weight: .bold)
                  .foregroundStyle(.secondary)
                Text(latest.planned.formatted(.currency(code: "USD")))
                  .font(.headline.bold())
              }

              VStack(alignment: .leading, spacing: 4) {
                Text("ACTUAL")
                  .typography(.nano, weight: .bold)
                  .foregroundStyle(.secondary)
                Text(latest.actual.formatted(.currency(code: "USD")))
                  .font(.headline.bold())
                  .foregroundStyle(latest.actual > latest.planned ? .red : .primary)
              }

              VStack(alignment: .leading, spacing: 4) {
                Text("REMAINING")
                  .typography(.nano, weight: .bold)
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
        .typography(.nano, weight: .bold)
        .foregroundStyle(.secondary)
      Text("Plan \(planned.currency)")
        .font(.caption)
      Text("Actual \(actual.currency)")
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
                .typography(.nano, weight: .bold)
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
                  outerRadius: .ratio(1.0),
                  angularInset: 2
                )
                .foregroundStyle(.green.gradient)

                SectorMark(
                  angle: .value("Amount", latest.actual),
                  innerRadius: .ratio(0.6),
                  outerRadius: .ratio(1.0),
                  angularInset: 2
                )
                .foregroundStyle(AppTheme.Colors.secondaryTint(for: colorScheme).gradient)
              }
            }
            .frame(minHeight: 180)
            .overlay {
              VStack(spacing: 4) {
                Text("Savings Rate")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                Text("\(Int(savingsRate))%")
                  .font(.largeTitle.bold()).fontDesign(.rounded)
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
            .frame(minHeight: 200)

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

  private static let monthStartParser: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f
  }()

  private func monthLabel(for monthStart: String) -> String {
    guard let date = Self.monthStartParser.date(from: monthStart) else { return monthStart }
    return date.formatted(.dateTime.month(.abbreviated))
  }
}

// MARK: - Pillar Detail Sheet

private struct PillarDetailSheet: View {
  let pillar: BudgetPillar
  let summary: PillarPlanningSummaryResponse
  let monthSummary: BudgetMonthSummary
  let partnerName: String
  
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme
  
  private var percentage: Double {
    guard summary.plannedAmount > 0 else { return 0 }
    return (summary.actualAmount / summary.plannedAmount) * 100
  }
  
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          VStack(spacing: 16) {
            Circle()
              .fill(pillar.color(for: colorScheme).opacity(0.2))
              .frame(width: 80, height: 80)
              .overlay {
                Image(systemName: pillar.symbol)
                  .font(.system(size: 36))
                  .foregroundStyle(pillar.color(for: colorScheme))
              }
            
            Text(pillar.title)
              .font(.title.bold())
            
            Text(pillar.subtitle)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 32)
          }
          .padding(.top, 20)
          
          GlassCard(cornerRadius: 20) {
            VStack(spacing: 16) {
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text("ACTUAL SPENDING")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  Text(summary.actualAmount.formatted(.currency(code: "USD")))
                    .font(.title2.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                  Text("BUDGET")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  Text(summary.plannedAmount.formatted(.currency(code: "USD")))
                    .font(.title2.bold())
                }
              }
              
              Divider().opacity(0.1)
              
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text("Budget usage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  Spacer()
                  Text("\(Int(percentage))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(percentage > 100 ? .red : .primary)
                }
                
                ProgressBar(
                  value: summary.actualAmount,
                  total: summary.plannedAmount,
                  color: percentage > 100 ? .red : pillar.color(for: colorScheme),
                  height: 8
                )
              }
            }
            .padding(20)
          }
          
          GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 16) {
              Text("BREAKDOWN")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
              
              HStack {
                VStack(alignment: .leading, spacing: 8) {
                  Text("My spending")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                  Text((monthSummary.myPillarActuals[pillar] ?? 0).formatted(.currency(code: "USD")))
                    .font(.headline.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                  Text("\(partnerName)'s spending")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                  Text((monthSummary.partnerPillarActuals[pillar] ?? 0).formatted(.currency(code: "USD")))
                    .font(.headline.bold())
                }
              }
              
              Divider().opacity(0.1)
              
              HStack {
                VStack(alignment: .leading, spacing: 8) {
                  Text("My plan")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                  Text((monthSummary.myPillarPlans[pillar] ?? 0).formatted(.currency(code: "USD")))
                    .font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                  Text("\(partnerName)'s plan")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                  Text((monthSummary.partnerPillarPlans[pillar] ?? 0).formatted(.currency(code: "USD")))
                    .font(.headline)
                }
              }
            }
            .padding(20)
          }
          
          if percentage > 100 {
            GlassCard(cornerRadius: 20) {
              HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundStyle(.red)
                  .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                  Text("Over Budget")
                    .font(.headline)
                  Text("You've exceeded your \(pillar.title) budget by \((summary.actualAmount - summary.plannedAmount).formatted(.currency(code: "USD")))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
              }
              .padding(20)
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
      }
      .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
      .navigationTitle(monthSummary.longLabel)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }
}

// MARK: - Quick Stats Card

private struct QuickStatsCard: View {
  let summary: BudgetMonthSummary
  let stats: ImportedStocksStatisticsDTO?
  @Environment(\.colorScheme) private var colorScheme
  
  private var savingsRate: Double {
    guard summary.salary > 0 else { return 0 }
    return ((summary.salary - summary.actual) / summary.salary) * 100
  }
  
  private var budgetUsage: Double {
    guard summary.planned > 0 else { return 0 }
    return (summary.actual / summary.planned) * 100
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Quick Stats")
        .font(.title3.bold())
      
      GlassCard(cornerRadius: 20) {
        VStack(spacing: 16) {
          HStack(spacing: 16) {
            QuickStatItem(
              icon: "chart.line.uptrend.xyaxis",
              title: "Savings Rate",
              value: "\(Int(savingsRate))%",
              color: savingsRate >= 20 ? .green : .orange
            )
            
            Divider()
            
            QuickStatItem(
              icon: "creditcard",
              title: "Budget Used",
              value: "\(Int(budgetUsage))%",
              color: budgetUsage > 100 ? .red : .blue
            )
          }
          
          Divider().opacity(0.1)
          
          HStack(spacing: 16) {
            QuickStatItem(
              icon: "briefcase",
              title: "Portfolio",
              value: (stats?.totalMarketValue ?? 0).compactCurrency(),
              color: .green
            )
            
            Divider()
            
            QuickStatItem(
              icon: "square.stack.3d.up",
              title: "Positions",
              value: "\(stats?.totalPositions ?? 0)",
              color: .purple
            )
          }
        }
        .padding(20)
      }
    }
  }
}

private struct QuickStatItem: View {
  let icon: String
  let title: String
  let value: String
  let color: Color
  
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundStyle(color)
      
      Text(value)
        .font(.title2.bold())
        .foregroundStyle(color)
      
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }
}

// MARK: - Smart Insights Card

private struct SmartInsightsCard: View {
  let summary: BudgetMonthSummary?
  let stats: ImportedStocksStatisticsDTO?
  @Environment(\.colorScheme) private var colorScheme
  
  private var insights: [Insight] {
    var result: [Insight] = []
    
    if let summary {
      let savingsRate = summary.salary > 0 ? ((summary.salary - summary.actual) / summary.salary) * 100 : 0
      
      if savingsRate >= 30 {
        result.append(Insight(
          icon: "star.fill",
          text: "Excellent! You're saving \(Int(savingsRate))% of your income",
          color: .green
        ))
      } else if savingsRate < 10 && summary.salary > 0 {
        result.append(Insight(
          icon: "exclamationmark.triangle.fill",
          text: "Low savings rate (\(Int(savingsRate))%). Consider reducing expenses",
          color: .orange
        ))
      }
      
      if summary.actual > summary.planned && summary.planned > 0 {
        let overspend = summary.actual - summary.planned
        result.append(Insight(
          icon: "exclamationmark.circle.fill",
          text: "Over budget by \(overspend.currency)",
          color: .red
        ))
      }
      
      let fundamentalsActual = summary.pillarActuals[.fundamentals] ?? 0
      let fundamentalsTarget = summary.salary * 0.5
      if fundamentalsActual > fundamentalsTarget * 1.2 {
        result.append(Insight(
          icon: "house.fill",
          text: "Fundamentals spending is 20% above target",
          color: .orange
        ))
      }
    }
    
    if let stats, stats.totalPositions > 0 {
      let pnlPercent = stats.totalCostBasis > 0 ? (stats.totalUnrealizedPnl / stats.totalCostBasis) * 100 : 0
      if pnlPercent > 20 {
        result.append(Insight(
          icon: "chart.line.uptrend.xyaxis",
          text: "Portfolio up \(Int(pnlPercent))%! Consider rebalancing",
          color: .green
        ))
      }
    }
    
    if result.isEmpty {
      result.append(Insight(
        icon: "chart.bar.doc.horizontal",
        text: "Add expense and portfolio data to unlock insights",
        color: .secondary
      ))
    }
    
    return result
  }
  
  struct Insight: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let color: Color
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Insights")
        .font(.title3.bold())
      
      GlassCard(cornerRadius: 20) {
        VStack(alignment: .leading, spacing: 16) {
          ForEach(insights) { insight in
            HStack(alignment: .top, spacing: 12) {
              Image(systemName: insight.icon)
                .font(.title3)
                .foregroundStyle(insight.color)
                .frame(width: 24)
              
              Text(insight.text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
              
              Spacer()
            }
            
            if insight.id != insights.last?.id {
              Divider().opacity(0.1)
            }
          }
        }
        .padding(20)
      }
    }
  }
}
