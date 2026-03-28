import Combine
import Foundation

@MainActor
final class BudgetPlannerViewModel: ObservableObject {
  @Published private(set) var monthlySnapshots: [MonthlyBudgetSnapshot]
  @Published private(set) var activities: [BudgetActivity]
  @Published var selectedMonthStart: Date

  private let calendar: Calendar

  init(
    // to fill from endpoint later
    monthlySnapshots: [MonthlyBudgetSnapshot] = BudgetPlannerViewModel.sampleSnapshots(),
    // to fill from endpoint later
    activities: [BudgetActivity] = BudgetPlannerViewModel.sampleActivities()
  ) {
    let calendar = Calendar(identifier: .gregorian)
    let sortedSnapshots = monthlySnapshots.sorted { $0.monthStart < $1.monthStart }
    let sortedActivities = activities.sorted { $0.occurredOn > $1.occurredOn }
    let initialMonthStart = sortedSnapshots.last?.monthStart ?? calendar.startOfMonth(for: .now)

    self.calendar = calendar
    self.monthlySnapshots = sortedSnapshots
    self.activities = sortedActivities
    self.selectedMonthStart = initialMonthStart
  }

  var availableMonths: [Date] {
    monthlySnapshots.map(\.monthStart).sorted(by: >)
  }

  var availableYears: [Int] {
    Array(
      Set(
        monthlySnapshots.map { snapshot in
          calendar.component(.year, from: snapshot.monthStart)
        }
      )
    )
    .sorted(by: >)
  }

  var selectedYear: Int {
    calendar.component(.year, from: selectedMonthStart)
  }

  var selectedMonthSnapshot: MonthlyBudgetSnapshot {
    monthlySnapshots[selectedMonthIndex]
  }

  var selectedYearSummaries: [BudgetMonthSummary] {
    summaries(forYear: selectedYear)
  }

  var selectedYearActualTotal: Double {
    selectedYearSummaries.reduce(0) { $0 + $1.actual }
  }

  var selectedYearAverageActual: Double {
    guard !selectedYearSummaries.isEmpty else { return 0 }
    return selectedYearActualTotal / Double(selectedYearSummaries.count)
  }

  var selectedYearLastMonthLabel: String {
    selectedYearSummaries.last?.monthStart.formatted(.dateTime.month(.abbreviated)) ?? "No data"
  }

  var selectedYearChartPoints: [BudgetMonthChartPoint] {
    let year = selectedYear
    let summariesByMonth = Dictionary(
      uniqueKeysWithValues: selectedYearSummaries.map {
        (calendar.component(.month, from: $0.monthStart), $0)
      }
    )

    return (1...12).compactMap { month in
      guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
        return nil
      }

      return BudgetMonthChartPoint(
        monthStart: monthStart,
        label: monthStart.formatted(.dateTime.month(.narrow)),
        actual: summariesByMonth[month]?.actual ?? 0
      )
    }
  }

  var selectedMonthActivities: [BudgetActivity] {
    activitiesForMonth(selectedMonthStart)
      .sorted { $0.occurredOn > $1.occurredOn }
  }

  var selectedMonthSummaries: [PillarPlanningSummary] {
    BudgetPillar.allCases.map { pillar in
      PillarPlanningSummary(
        pillar: pillar,
        targetAmount: targetAmount(for: pillar, monthStart: selectedMonthStart),
        plannedAmount: plannedTotal(for: pillar, monthStart: selectedMonthStart),
        actualAmount: actualTotal(for: pillar, monthStart: selectedMonthStart),
        unplannedActualAmount: unplannedActual(for: pillar, monthStart: selectedMonthStart)
      )
    }
  }

  var selectedMonthPlannedTotal: Double {
    selectedMonthSnapshot.items.reduce(0) { $0 + $1.plannedAmount }
  }

  var selectedMonthActualTotal: Double {
    actualTotal(for: selectedMonthStart)
  }

  var selectedMonthRemainingToAllocate: Double {
    selectedMonthSnapshot.netSalary - selectedMonthPlannedTotal
  }

  var selectedMonthAvailableAfterPillarPlan: Double {
    selectedMonthRemainingToAllocate
  }

  var selectedMonthLeftAfterSpending: Double {
    selectedMonthSnapshot.netSalary - selectedMonthActualTotal
  }

  var monthlySummaries: [BudgetMonthSummary] {
    monthlySnapshots.map { snapshot in
      BudgetMonthSummary(
        monthStart: snapshot.monthStart,
        planned: snapshot.items.reduce(0) { $0 + $1.plannedAmount },
        actual: actualTotal(for: snapshot.monthStart),
        salary: snapshot.netSalary,
        pillarActuals: Dictionary(
          uniqueKeysWithValues: BudgetPillar.allCases.map {
            ($0, actualTotal(for: $0, monthStart: snapshot.monthStart))
          }
        ),
        pillarPlans: Dictionary(
          uniqueKeysWithValues: BudgetPillar.allCases.map {
            ($0, plannedTotal(for: $0, monthStart: snapshot.monthStart))
          }
        )
      )
    }
  }

  var yearlySummaries: [BudgetYearSummary] {
    let grouped = Dictionary(grouping: monthlySummaries) {
      calendar.component(.year, from: $0.monthStart)
    }

    return grouped.keys.sorted().map { year in
      let summaries = grouped[year] ?? []
      return BudgetYearSummary(
        year: year,
        planned: summaries.reduce(0) { $0 + $1.planned },
        actual: summaries.reduce(0) { $0 + $1.actual },
        salary: summaries.reduce(0) { $0 + $1.salary }
      )
    }
  }

  var selectedMonthDisplayTitle: String {
    selectedMonthStart.formatted(.dateTime.month(.wide).year())
  }

  func selectMonth(_ monthStart: Date) {
    selectedMonthStart = calendar.startOfMonth(for: monthStart)
  }

  func selectYear(_ year: Int) {
    guard let latestMonthInYear = summaries(forYear: year).last?.monthStart else { return }
    selectedMonthStart = latestMonthInYear
  }

  func createNextMonthPlan() {
    let nextMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonthSnapshot.monthStart) ?? .now
    let nextMonthStart = calendar.startOfMonth(for: nextMonth)

    guard !monthlySnapshots.contains(where: { calendar.isDate($0.monthStart, equalTo: nextMonthStart, toGranularity: .month) }) else {
      selectedMonthStart = nextMonthStart
      return
    }

    let template = selectedMonthSnapshot
    monthlySnapshots.append(
      MonthlyBudgetSnapshot(
        monthStart: nextMonthStart,
        netSalary: template.netSalary,
        targetShares: template.targetShares,
        items: template.items.map {
          BudgetPlanItem(title: $0.title, plannedAmount: $0.plannedAmount, pillar: $0.pillar)
        }
      )
    )
    monthlySnapshots.sort { $0.monthStart < $1.monthStart }
    selectedMonthStart = nextMonthStart
  }

  func updateNetSalary(_ amount: Double) {
    monthlySnapshots[selectedMonthIndex].netSalary = max(amount, 0)
  }

  func updateTargetShares(_ shares: [BudgetPillar: Double]) {
    let normalized = normalizeShares(shares)
    monthlySnapshots[selectedMonthIndex].targetShares = normalized
  }

  func addOrUpdatePlanItem(_ draft: BudgetPlanItemDraft) {
    let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { return }

    if let itemID = draft.itemID,
      let existingIndex = monthlySnapshots[selectedMonthIndex].items.firstIndex(where: { $0.id == itemID })
    {
      monthlySnapshots[selectedMonthIndex].items[existingIndex].title = title
      monthlySnapshots[selectedMonthIndex].items[existingIndex].plannedAmount = max(draft.plannedAmount, 0)
      monthlySnapshots[selectedMonthIndex].items[existingIndex].pillar = draft.pillar
    } else {
      monthlySnapshots[selectedMonthIndex].items.append(
        BudgetPlanItem(
          title: title,
          plannedAmount: max(draft.plannedAmount, 0),
          pillar: draft.pillar
        )
      )
    }

    monthlySnapshots[selectedMonthIndex].items.sort {
      if $0.pillar == $1.pillar {
        return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
      }
      return $0.pillar.rawValue < $1.pillar.rawValue
    }
  }

  func removePlanItem(_ itemID: UUID) {
    monthlySnapshots[selectedMonthIndex].items.removeAll { $0.id == itemID }
  }

  func recordExpense(_ draft: BudgetActivityDraft) {
    let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { return }

    ensureMonthExists(for: draft.occurredOn)

    activities.insert(
      BudgetActivity(
        title: title,
        amount: max(draft.amount, 0),
        pillar: draft.pillar,
        occurredOn: draft.occurredOn,
        linkedPlanItemID: draft.linkedPlanItemID
      ),
      at: 0
    )

    let activityMonth = calendar.startOfMonth(for: draft.occurredOn)
    if calendar.isDate(activityMonth, equalTo: selectedMonthStart, toGranularity: .month) {
      selectedMonthStart = activityMonth
    }
  }

  func items(for pillar: BudgetPillar, monthStart: Date? = nil) -> [BudgetPlanItem] {
    let month = monthStart ?? selectedMonthStart
    guard let snapshot = snapshot(for: month) else { return [] }
    return snapshot.items.filter { $0.pillar == pillar }
  }

  func actualAmount(for item: BudgetPlanItem, monthStart: Date? = nil) -> Double {
    let month = monthStart ?? selectedMonthStart
    return activitiesForMonth(month)
      .filter { activity in
        if let linkedPlanItemID = activity.linkedPlanItemID {
          return linkedPlanItemID == item.id
        }

        return activity.pillar == item.pillar
          && activity.title.normalizedBudgetKey == item.title.normalizedBudgetKey
      }
      .reduce(0) { $0 + $1.amount }
  }

  func actualTotal(for pillar: BudgetPillar, monthStart: Date) -> Double {
    activitiesForMonth(monthStart)
      .filter { $0.pillar == pillar }
      .reduce(0) { $0 + $1.amount }
  }

  func actualTotal(for monthStart: Date) -> Double {
    activitiesForMonth(monthStart)
      .reduce(0) { $0 + $1.amount }
  }

  func plannedTotal(for pillar: BudgetPillar, monthStart: Date) -> Double {
    items(for: pillar, monthStart: monthStart)
      .reduce(0) { $0 + $1.plannedAmount }
  }

  func targetAmount(for pillar: BudgetPillar, monthStart: Date) -> Double {
    guard let snapshot = snapshot(for: monthStart) else { return 0 }
    return snapshot.netSalary * (snapshot.targetShares[pillar] ?? pillar.defaultTargetShare)
  }

  func unplannedActual(for pillar: BudgetPillar, monthStart: Date) -> Double {
    let plannedItems = items(for: pillar, monthStart: monthStart)

    return activitiesForMonth(monthStart)
      .filter { activity in
        guard activity.pillar == pillar else { return false }

        if let linkedPlanItemID = activity.linkedPlanItemID {
          return !plannedItems.contains(where: { $0.id == linkedPlanItemID })
        }

        return !plannedItems.contains {
          $0.title.normalizedBudgetKey == activity.title.normalizedBudgetKey
        }
      }
      .reduce(0) { $0 + $1.amount }
  }

  private var selectedMonthIndex: Int {
    if let index = monthlySnapshots.firstIndex(where: {
      calendar.isDate($0.monthStart, equalTo: selectedMonthStart, toGranularity: .month)
    }) {
      return index
    }

    return max(monthlySnapshots.indices.last ?? 0, 0)
  }

  private func snapshot(for monthStart: Date) -> MonthlyBudgetSnapshot? {
    monthlySnapshots.first {
      calendar.isDate($0.monthStart, equalTo: monthStart, toGranularity: .month)
    }
  }

  private func activitiesForMonth(_ monthStart: Date) -> [BudgetActivity] {
    activities.filter {
      calendar.isDate($0.occurredOn, equalTo: monthStart, toGranularity: .month)
    }
  }

  private func ensureMonthExists(for date: Date) {
    let monthStart = calendar.startOfMonth(for: date)

    guard snapshot(for: monthStart) == nil else { return }

    let template = monthlySnapshots.last ?? MonthlyBudgetSnapshot(
      monthStart: monthStart,
      netSalary: 2700,
      items: []
    )

    monthlySnapshots.append(
      MonthlyBudgetSnapshot(
        monthStart: monthStart,
        netSalary: template.netSalary,
        targetShares: template.targetShares,
        items: template.items.map {
          BudgetPlanItem(title: $0.title, plannedAmount: $0.plannedAmount, pillar: $0.pillar)
        }
      )
    )
    monthlySnapshots.sort { $0.monthStart < $1.monthStart }
  }

  private func normalizeShares(_ shares: [BudgetPillar: Double]) -> [BudgetPillar: Double] {
    let sanitized = Dictionary(uniqueKeysWithValues: BudgetPillar.allCases.map { pillar in
      (pillar, max(shares[pillar] ?? pillar.defaultTargetShare, 0))
    })
    let total = sanitized.values.reduce(0, +)

    guard total > 0 else { return BudgetPillar.defaultShares }

    return Dictionary(uniqueKeysWithValues: sanitized.map { key, value in
      (key, value / total)
    })
  }

  private func summaries(forYear year: Int) -> [BudgetMonthSummary] {
    monthlySummaries
      .filter { summary in
        calendar.component(.year, from: summary.monthStart) == year
      }
      .sorted { $0.monthStart < $1.monthStart }
  }

  // to fill from endpoint later
  nonisolated private static func sampleSnapshots() -> [MonthlyBudgetSnapshot] {
    let calendar = Calendar(identifier: .gregorian)
    let months = [
      DateComponents(year: 2025, month: 11, day: 1),
      DateComponents(year: 2025, month: 12, day: 1),
      DateComponents(year: 2026, month: 1, day: 1),
      DateComponents(year: 2026, month: 2, day: 1),
      DateComponents(year: 2026, month: 3, day: 1),
    ]

    let salaries: [Double] = [2550, 2600, 2700, 2720, 2700]

    return months.enumerated().compactMap { index, components in
      guard let date = calendar.date(from: components) else { return nil }

      let rent = [980.0, 980.0, 980.0, 980.0, 980.0][index]
      let utilities = [145.0, 152.0, 148.0, 149.0, 150.0][index]
      let groceries = [280.0, 295.0, 290.0, 300.0, 305.0][index]
      let investments = [300.0, 320.0, 340.0, 350.0, 360.0][index]
      let travel = [90.0, 110.0, 120.0, 95.0, 105.0][index]
      let dining = [80.0, 105.0, 95.0, 85.0, 100.0][index]

      return MonthlyBudgetSnapshot(
        monthStart: date,
        netSalary: salaries[index],
        items: [
          BudgetPlanItem(title: "Rent", plannedAmount: rent, pillar: .fundamentals),
          BudgetPlanItem(title: "Internet", plannedAmount: 38, pillar: .fundamentals),
          BudgetPlanItem(title: "Utilities", plannedAmount: utilities, pillar: .fundamentals),
          BudgetPlanItem(title: "Groceries", plannedAmount: groceries, pillar: .fundamentals),
          BudgetPlanItem(title: "ETF investment", plannedAmount: investments, pillar: .futureYou),
          BudgetPlanItem(title: "Emergency fund", plannedAmount: 120, pillar: .futureYou),
          BudgetPlanItem(title: "Dining out", plannedAmount: dining, pillar: .fun),
          BudgetPlanItem(title: "Travel sinking fund", plannedAmount: travel, pillar: .fun),
        ]
      )
    }
  }

  // to fill from endpoint later
  nonisolated private static func sampleActivities() -> [BudgetActivity] {
    let calendar = Calendar(identifier: .gregorian)

    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
      calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    return [
      BudgetActivity(title: "Rent", amount: 980, pillar: .fundamentals, occurredOn: date(2025, 11, 2)),
      BudgetActivity(title: "Groceries", amount: 264, pillar: .fundamentals, occurredOn: date(2025, 11, 14)),
      BudgetActivity(title: "ETF investment", amount: 300, pillar: .futureYou, occurredOn: date(2025, 11, 4)),
      BudgetActivity(title: "Dining out", amount: 76, pillar: .fun, occurredOn: date(2025, 11, 19)),
      BudgetActivity(title: "Rent", amount: 980, pillar: .fundamentals, occurredOn: date(2025, 12, 2)),
      BudgetActivity(title: "Groceries", amount: 310, pillar: .fundamentals, occurredOn: date(2025, 12, 15)),
      BudgetActivity(title: "ETF investment", amount: 320, pillar: .futureYou, occurredOn: date(2025, 12, 6)),
      BudgetActivity(title: "Travel sinking fund", amount: 110, pillar: .fun, occurredOn: date(2025, 12, 20)),
      BudgetActivity(title: "Rent", amount: 980, pillar: .fundamentals, occurredOn: date(2026, 1, 2)),
      BudgetActivity(title: "Internet", amount: 38, pillar: .fundamentals, occurredOn: date(2026, 1, 7)),
      BudgetActivity(title: "Groceries", amount: 286, pillar: .fundamentals, occurredOn: date(2026, 1, 17)),
      BudgetActivity(title: "ETF investment", amount: 340, pillar: .futureYou, occurredOn: date(2026, 1, 5)),
      BudgetActivity(title: "Dining out", amount: 92, pillar: .fun, occurredOn: date(2026, 1, 24)),
      BudgetActivity(title: "Rent", amount: 980, pillar: .fundamentals, occurredOn: date(2026, 2, 2)),
      BudgetActivity(title: "Utilities", amount: 155, pillar: .fundamentals, occurredOn: date(2026, 2, 11)),
      BudgetActivity(title: "Groceries", amount: 298, pillar: .fundamentals, occurredOn: date(2026, 2, 15)),
      BudgetActivity(title: "ETF investment", amount: 350, pillar: .futureYou, occurredOn: date(2026, 2, 4)),
      BudgetActivity(title: "Dining out", amount: 82, pillar: .fun, occurredOn: date(2026, 2, 13)),
      BudgetActivity(title: "Rent", amount: 980, pillar: .fundamentals, occurredOn: date(2026, 3, 2)),
      BudgetActivity(title: "Internet", amount: 38, pillar: .fundamentals, occurredOn: date(2026, 3, 6)),
      BudgetActivity(title: "Utilities", amount: 149, pillar: .fundamentals, occurredOn: date(2026, 3, 10)),
      BudgetActivity(title: "Groceries", amount: 301, pillar: .fundamentals, occurredOn: date(2026, 3, 14)),
      BudgetActivity(title: "ETF investment", amount: 360, pillar: .futureYou, occurredOn: date(2026, 3, 5)),
      BudgetActivity(title: "Dining out", amount: 96, pillar: .fun, occurredOn: date(2026, 3, 18)),
      BudgetActivity(title: "Weekend trip", amount: 88, pillar: .fun, occurredOn: date(2026, 3, 21)),
    ]
  }
}

private extension Calendar {
  func startOfMonth(for date: Date) -> Date {
    self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
  }
}

private extension String {
  var normalizedBudgetKey: String {
    trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
}
