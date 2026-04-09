import Foundation
import StockPlanShared
import XCTest

@testable import financeplan

final class BudgetPlannerViewModelTests: XCTestCase {
  private let calendar = Calendar(identifier: .gregorian)
  private let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    return formatter
  }()

  func testSelectedMonthUsesSalaryAndPillarTargetsToComputeAvailability() async {
    await MainActor.run {
      let month = makeMonth(2026, 3)
      let snapshot = MonthlyBudgetSnapshot(
        monthStart: month,
        netSalary: 3000,
        targetShares: [
          .fundamentals: 0.5,
          .futureYou: 0.2,
          .fun: 0.3,
        ],
        items: [
          BudgetPlanItem(title: "Rent", plannedAmount: 1100, pillar: .fundamentals),
          BudgetPlanItem(title: "ETF", plannedAmount: 400, pillar: .futureYou),
          BudgetPlanItem(title: "Dining", plannedAmount: 300, pillar: .fun),
        ]
      )

      let viewModel = BudgetPlannerViewModel(monthlySnapshots: [snapshot], activities: [])
      let summaries = Dictionary(uniqueKeysWithValues: viewModel.selectedMonthSummaries.map { ($0.pillar, $0) })
      guard
        let fundamentalsSummary = summaries[.fundamentals],
        let futureYouSummary = summaries[.futureYou],
        let funSummary = summaries[.fun]
      else {
        XCTFail("Expected all pillar summaries to exist.")
        return
      }

      XCTAssertEqual(viewModel.selectedMonthPlannedTotal, 1800, accuracy: 0.001)
      XCTAssertEqual(viewModel.selectedMonthAvailableAfterPillarPlan, 1200, accuracy: 0.001)
      XCTAssertEqual(fundamentalsSummary.targetAmount, 1500, accuracy: 0.001)
      XCTAssertEqual(futureYouSummary.availableToPlan, 200, accuracy: 0.001)
      XCTAssertEqual(funSummary.availableToPlan, 600, accuracy: 0.001)
    }
  }

  func testRecordExpenseUpdatesActualTotalsAndMoneyLeft() async {
    let mock = BudgetPlannerServiceMock()
    let month = makeMonth(2026, 3)
    let occurredOn = makeDate(2026, 3, 2)
    let rent = BudgetPlanItem(id: UUID(), title: "Rent", plannedAmount: 1100, pillar: .fundamentals)
    let snapshot = MonthlyBudgetSnapshot(
      monthStart: month,
      netSalary: 3000,
      items: [rent]
    )
    mock.createExpenseResult = .success(
      ExpenseResponse(
        id: UUID().uuidString,
        title: "Rent",
        amount: 980,
        pillar: .fundamentals,
        occurredOn: formattedDayString(occurredOn),
        linkedPlanItemId: rent.id.uuidString,
        splitMode: .personal,
        userSharePercent: 100,
        createdAt: nil,
        updatedAt: nil
      )
    )

    let viewModel = await MainActor.run {
      BudgetPlannerViewModel(monthlySnapshots: [snapshot], activities: [], expensesService: mock)
    }
    let didSave = await viewModel.recordExpenseAndWait(
      BudgetActivityDraft(
        title: "Rent",
        amount: 980,
        pillar: .fundamentals,
        occurredOn: occurredOn,
        linkedPlanItemID: rent.id
      )
    )

    await MainActor.run {
      XCTAssertTrue(didSave)
      XCTAssertEqual(viewModel.actualAmount(for: rent), 980, accuracy: 0.001)
      XCTAssertEqual(viewModel.selectedMonthActualTotal, 980, accuracy: 0.001)
      XCTAssertEqual(viewModel.selectedMonthLeftAfterSpending, 2020, accuracy: 0.001)
    }
  }

  func testCreateNextMonthPlanCopiesSalaryTargetsAndItems() async {
    await MainActor.run {
      let march = makeMonth(2026, 3)
      let snapshot = MonthlyBudgetSnapshot(
        monthStart: march,
        netSalary: 2700,
        targetShares: [
          .fundamentals: 0.45,
          .futureYou: 0.30,
          .fun: 0.25,
        ],
        items: [
          BudgetPlanItem(title: "Rent", plannedAmount: 980, pillar: .fundamentals),
          BudgetPlanItem(title: "ETF", plannedAmount: 350, pillar: .futureYou),
        ]
      )

      let viewModel = BudgetPlannerViewModel(monthlySnapshots: [snapshot], activities: [])
      viewModel.createNextMonthPlan()

      XCTAssertEqual(viewModel.availableMonths.count, 2)
      guard let selectedSnapshot = viewModel.selectedMonthSnapshot else {
        XCTFail("Expected selected month snapshot.")
        return
      }
      XCTAssertEqual(selectedSnapshot.netSalary, 2700, accuracy: 0.001)
      XCTAssertEqual(selectedSnapshot.items.count, 2)
      guard let futureYouTarget = selectedSnapshot.targetShares[.futureYou] else {
        XCTFail("Expected Future You target share.")
        return
      }
      XCTAssertEqual(futureYouTarget, 0.30, accuracy: 0.001)
      XCTAssertEqual(
        viewModel.selectedMonthStart,
        calendar.date(byAdding: .month, value: 1, to: march)
      )
    }
  }

  func testSelectYearBuildsYearSummaryAndMovesSelectionToLatestMonthInYear() async {
    await MainActor.run {
      let december2025 = makeMonth(2025, 12)
      let january2026 = makeMonth(2026, 1)
      let march2026 = makeMonth(2026, 3)

      let snapshots = [
        MonthlyBudgetSnapshot(monthStart: december2025, netSalary: 2600, items: []),
        MonthlyBudgetSnapshot(monthStart: january2026, netSalary: 2700, items: []),
        MonthlyBudgetSnapshot(monthStart: march2026, netSalary: 2800, items: []),
      ]

      let activities = [
        BudgetActivity(title: "December spend", amount: 900, pillar: .fundamentals, occurredOn: makeDate(2025, 12, 5)),
        BudgetActivity(title: "January spend", amount: 1100, pillar: .fundamentals, occurredOn: makeDate(2026, 1, 5)),
        BudgetActivity(title: "March spend", amount: 1300, pillar: .fun, occurredOn: makeDate(2026, 3, 6)),
      ]

      let viewModel = BudgetPlannerViewModel(monthlySnapshots: snapshots, activities: activities)

      viewModel.selectYear(2025)

      XCTAssertEqual(viewModel.selectedYear, 2025)
      XCTAssertEqual(viewModel.selectedMonthStart, december2025)
      XCTAssertEqual(viewModel.selectedYearSummaries.count, 1)
      XCTAssertEqual(viewModel.selectedYearActualTotal, 900, accuracy: 0.001)
      XCTAssertEqual(viewModel.selectedYearChartPoints.count, 12)
      XCTAssertEqual(
        viewModel.selectedYearChartPoints[11].actual,
        900,
        accuracy: 0.001
      )
    }
  }

  func testMonthsWithExpensesAreAvailableEvenWithoutSnapshot() async {
    await MainActor.run {
      let april = makeMonth(2026, 4)
      let may = makeMonth(2026, 5)

      let snapshots = [
        MonthlyBudgetSnapshot(monthStart: april, netSalary: 3000, items: [])
      ]
      let activities = [
        BudgetActivity(
          title: "Rent",
          amount: 700,
          pillar: .fundamentals,
          occurredOn: makeDate(2026, 5, 8)
        )
      ]

      let viewModel = BudgetPlannerViewModel(monthlySnapshots: snapshots, activities: activities)

      XCTAssertEqual(viewModel.availableMonths.count, 2)
      XCTAssertEqual(viewModel.availableMonths.first, may)
      XCTAssertEqual(viewModel.selectedMonthStart, may)
      XCTAssertEqual(viewModel.selectedMonthActivities.count, 1)
      XCTAssertNil(viewModel.selectedMonthSnapshot)
      XCTAssertEqual(viewModel.selectedMonthActualTotal, 700, accuracy: 0.001)
    }
  }

  func testDeleteCurrentSnapshotDoesNotDeleteDifferentMonthByFallback() async {
    await MainActor.run {
      let april = makeMonth(2026, 4)
      let may = makeMonth(2026, 5)
      let snapshots = [
        MonthlyBudgetSnapshot(monthStart: april, netSalary: 3000, items: [])
      ]

      let viewModel = BudgetPlannerViewModel(monthlySnapshots: snapshots, activities: [])
      viewModel.selectMonth(may)
      viewModel.deleteCurrentSnapshot()

      XCTAssertEqual(viewModel.monthlySnapshots.count, 1)
      XCTAssertEqual(viewModel.monthlySnapshots.first?.monthStart, april)
      XCTAssertEqual(viewModel.errorMessage, "No monthly plan exists for the selected month.")
    }
  }

  func testRecordSharedExpenseCorrectlySplitsAmounts() async {
    let mock = BudgetPlannerServiceMock()
    let month = makeMonth(2026, 3)
    let occurredOn = makeDate(2026, 3, 1)
    let rent = BudgetPlanItem(
      id: UUID(), title: "Rent", plannedAmount: 1200,
      pillar: .fundamentals, splitMode: .shared, userSharePercent: 60
    )
    let snapshot = MonthlyBudgetSnapshot(
      monthStart: month, netSalary: 3000, items: [rent]
    )
    mock.createExpenseResult = .success(
      ExpenseResponse(
        id: UUID().uuidString,
        title: "Rent",
        amount: 1200,
        pillar: .fundamentals,
        occurredOn: formattedDayString(occurredOn),
        linkedPlanItemId: rent.id.uuidString,
        splitMode: .shared,
        userSharePercent: 60,
        createdAt: nil,
        updatedAt: nil
      )
    )

    let viewModel = await MainActor.run {
      BudgetPlannerViewModel(monthlySnapshots: [snapshot], activities: [], expensesService: mock)
    }
    let didSave = await viewModel.recordExpenseAndWait(
      BudgetActivityDraft(
        title: "Rent", amount: 1200, pillar: .fundamentals,
        occurredOn: occurredOn, linkedPlanItemID: rent.id,
        splitMode: .shared, userSharePercent: 60
      )
    )

    await MainActor.run {
      XCTAssertTrue(didSave)
      XCTAssertEqual(viewModel.selectedMonthActualTotal, 1200, accuracy: 0.001)
      XCTAssertEqual(viewModel.selectedMonthMyActualTotal, 720, accuracy: 0.001)
      XCTAssertEqual(viewModel.selectedMonthPartnerActualTotal, 480, accuracy: 0.001)
      XCTAssertEqual(viewModel.selectedMonthLeftAfterSpending, 1800, accuracy: 0.001)
    }
  }

  func testAddPlanItemWithSharedSplitReflectsInPillarSummary() async {
    await MainActor.run {
      let month = makeMonth(2026, 4)
      let mortgage = BudgetPlanItem(
        id: UUID(), title: "Mortgage", plannedAmount: 2000,
        pillar: .fundamentals, splitMode: .shared, userSharePercent: 50
      )
      let etf = BudgetPlanItem(
        id: UUID(), title: "ETF", plannedAmount: 500,
        pillar: .futureYou
      )
      let snapshot = MonthlyBudgetSnapshot(
        monthStart: month, netSalary: 5000,
        targetShares: [.fundamentals: 0.5, .futureYou: 0.2, .fun: 0.3],
        items: [mortgage, etf]
      )

      let viewModel = BudgetPlannerViewModel(monthlySnapshots: [snapshot], activities: [])
      let summaries = Dictionary(
        uniqueKeysWithValues: viewModel.selectedMonthSummaries.map { ($0.pillar, $0) }
      )

      // Fundamentals: target = 5000 * 0.5 = 2500, planned = 2000
      XCTAssertEqual(summaries[.fundamentals]?.targetAmount ?? 0, 2500, accuracy: 0.001)
      XCTAssertEqual(summaries[.fundamentals]?.plannedAmount ?? 0, 2000, accuracy: 0.001)
      XCTAssertEqual(summaries[.fundamentals]?.availableToPlan ?? 0, 500, accuracy: 0.001)

      // Total planned: 2500, my share: mortgage 1000 (50%) + etf 500 (100%) = 1500
      XCTAssertEqual(viewModel.selectedMonthPlannedTotal, 2500, accuracy: 0.001)
      XCTAssertEqual(viewModel.selectedMonthMyPlannedTotal, 1500, accuracy: 0.001)
      XCTAssertEqual(viewModel.selectedMonthPartnerPlannedTotal, 1000, accuracy: 0.001)  // mortgage 50%
      XCTAssertEqual(viewModel.selectedMonthAvailableAfterPillarPlan, 2500, accuracy: 0.001)
    }
  }

  func testMultipleExpensesAcrossPillarsAggregateCorrectly() async {
    await MainActor.run {
      let month = makeMonth(2026, 4)
      let snapshot = MonthlyBudgetSnapshot(
        monthStart: month, netSalary: 4000,
        targetShares: [.fundamentals: 0.5, .futureYou: 0.2, .fun: 0.3],
        items: [
          BudgetPlanItem(title: "Groceries", plannedAmount: 600, pillar: .fundamentals),
          BudgetPlanItem(title: "Savings", plannedAmount: 800, pillar: .futureYou),
          BudgetPlanItem(title: "Dining", plannedAmount: 400, pillar: .fun),
        ]
      )

      let activities = [
        BudgetActivity(title: "Groceries", amount: 550, pillar: .fundamentals, occurredOn: makeDate(2026, 4, 3)),
        BudgetActivity(title: "Uber Eats", amount: 35, pillar: .fun, occurredOn: makeDate(2026, 4, 5)),
        BudgetActivity(title: "Concert", amount: 120, pillar: .fun, occurredOn: makeDate(2026, 4, 8)),
      ]

      let viewModel = BudgetPlannerViewModel(monthlySnapshots: [snapshot], activities: activities)
      let summaries = Dictionary(
        uniqueKeysWithValues: viewModel.selectedMonthSummaries.map { ($0.pillar, $0) }
      )

      XCTAssertEqual(viewModel.selectedMonthActualTotal, 705, accuracy: 0.001)
      XCTAssertEqual(viewModel.selectedMonthLeftAfterSpending, 3295, accuracy: 0.001)

      // Fundamentals: actual 550
      XCTAssertEqual(summaries[.fundamentals]?.actualAmount ?? 0, 550, accuracy: 0.001)
      // Fun: actual 35 + 120 = 155
      XCTAssertEqual(summaries[.fun]?.actualAmount ?? 0, 155, accuracy: 0.001)
      // Future You: actual 0
      XCTAssertEqual(summaries[.futureYou]?.actualAmount ?? 0, 0, accuracy: 0.001)
    }
  }

  func testSharedExpensesAndPlanItemsSplitMyPartnerTotalsCorrectly() async {
    await MainActor.run {
      let month = makeMonth(2026, 5)
      let snapshot = MonthlyBudgetSnapshot(
        monthStart: month, netSalary: 6000,
        items: [
          BudgetPlanItem(title: "Rent", plannedAmount: 1500, pillar: .fundamentals, splitMode: .shared, userSharePercent: 40),
          BudgetPlanItem(title: "Gym", plannedAmount: 50, pillar: .fun),
        ]
      )

      let activities = [
        BudgetActivity(title: "Rent", amount: 1500, pillar: .fundamentals, occurredOn: makeDate(2026, 5, 1), splitMode: .shared, userSharePercent: 40),
        BudgetActivity(title: "Gym", amount: 50, pillar: .fun, occurredOn: makeDate(2026, 5, 3)),
      ]

      let viewModel = BudgetPlannerViewModel(monthlySnapshots: [snapshot], activities: activities)

      // Planned: Rent 1500 + Gym 50 = 1550
      XCTAssertEqual(viewModel.selectedMonthPlannedTotal, 1550, accuracy: 0.001)
      // My planned: Rent 600 (40%) + Gym 50 (100%) = 650
      XCTAssertEqual(viewModel.selectedMonthMyPlannedTotal, 650, accuracy: 0.001)
      // Partner planned: Rent 900 (60%) = 900
      XCTAssertEqual(viewModel.selectedMonthPartnerPlannedTotal, 900, accuracy: 0.001)

      // Actual: Rent 1500 + Gym 50 = 1550
      XCTAssertEqual(viewModel.selectedMonthActualTotal, 1550, accuracy: 0.001)
      // My actual: Rent 600 (40%) + Gym 50 (100%) = 650
      XCTAssertEqual(viewModel.selectedMonthMyActualTotal, 650, accuracy: 0.001)
      // Partner actual: Rent 900 (60%) = 900
      XCTAssertEqual(viewModel.selectedMonthPartnerActualTotal, 900, accuracy: 0.001)
    }
  }

  func testUpdateNetSalaryPropagatesToAvailableAfterPlanAndSpendImmediately() async {
    let mock = BudgetPlannerServiceMock()
    let month = makeMonth(2026, 4)
    let snapshotID = UUID()
    let snapshot = MonthlyBudgetSnapshot(
      id: snapshotID,
      monthStart: month,
      netSalary: 2000,
      targetShares: [.fundamentals: 0.5, .futureYou: 0.2, .fun: 0.3],
      items: [
        BudgetPlanItem(title: "Rent", plannedAmount: 700, pillar: .fundamentals),
      ]
    )
    let activities = [
      BudgetActivity(
        title: "Rent",
        amount: 650,
        pillar: .fundamentals,
        occurredOn: makeDate(2026, 4, 2)
      )
    ]
    mock.updateSnapshotResult = .success(
      BudgetSnapshotResponse(
        id: snapshotID.uuidString,
        monthStart: formattedDayString(month),
        netSalary: 2600,
        targetShares: [
          BudgetPillar.fundamentals.rawValue: 0.5,
          BudgetPillar.futureYou.rawValue: 0.2,
          BudgetPillar.fun.rawValue: 0.3,
        ],
        createdAt: nil,
        updatedAt: nil
      )
    )

    let viewModel = await MainActor.run {
      BudgetPlannerViewModel(monthlySnapshots: [snapshot], activities: activities, expensesService: mock)
    }

    await MainActor.run {
      viewModel.updateNetSalary(2600)
    }

    for _ in 0..<60 where mock.updateSnapshotRequests.isEmpty {
      try? await Task.sleep(for: .milliseconds(20))
    }

    await MainActor.run {
      XCTAssertEqual(viewModel.selectedMonthSnapshot?.netSalary ?? -1, 2600, accuracy: 0.001)
      XCTAssertEqual(viewModel.selectedMonthAvailableAfterPillarPlan, 1900, accuracy: 0.001)
      XCTAssertEqual(viewModel.selectedMonthLeftAfterSpending, 1950, accuracy: 0.001)
    }
    XCTAssertEqual(mock.updateSnapshotRequests.count, 1)
    XCTAssertEqual(mock.updateSnapshotRequests.first?.monthStart, formattedDayString(month))
  }

  func testUpdateTargetSharesPropagatesToPillarTargetsImmediately() async {
    let mock = BudgetPlannerServiceMock()
    let month = makeMonth(2026, 4)
    let snapshotID = UUID()
    let snapshot = MonthlyBudgetSnapshot(
      id: snapshotID,
      monthStart: month,
      netSalary: 3000,
      targetShares: [.fundamentals: 0.5, .futureYou: 0.2, .fun: 0.3],
      items: []
    )
    mock.updateSnapshotResult = .success(
      BudgetSnapshotResponse(
        id: snapshotID.uuidString,
        monthStart: formattedDayString(month),
        netSalary: 3000,
        targetShares: [
          BudgetPillar.fundamentals.rawValue: 0.6,
          BudgetPillar.futureYou.rawValue: 0.25,
          BudgetPillar.fun.rawValue: 0.15,
        ],
        createdAt: nil,
        updatedAt: nil
      )
    )

    let viewModel = await MainActor.run {
      BudgetPlannerViewModel(monthlySnapshots: [snapshot], activities: [], expensesService: mock)
    }

    await MainActor.run {
      viewModel.updateTargetShares([
        .fundamentals: 0.6,
        .futureYou: 0.25,
        .fun: 0.15,
      ])
    }

    for _ in 0..<60 where mock.updateSnapshotRequests.isEmpty {
      try? await Task.sleep(for: .milliseconds(20))
    }

    await MainActor.run {
      let summaries = Dictionary(uniqueKeysWithValues: viewModel.selectedMonthSummaries.map { ($0.pillar, $0) })
      XCTAssertEqual(summaries[.fundamentals]?.targetAmount ?? -1, 1800, accuracy: 0.001)
      XCTAssertEqual(summaries[.futureYou]?.targetAmount ?? -1, 750, accuracy: 0.001)
      XCTAssertEqual(summaries[.fun]?.targetAmount ?? -1, 450, accuracy: 0.001)
    }
    XCTAssertEqual(mock.updateSnapshotRequests.count, 1)
    XCTAssertEqual(mock.updateSnapshotRequests.first?.monthStart, formattedDayString(month))
  }

  func testLoadShowsSuggestionsLoadingAndThenPopulatesSuggestion() async {
    let mock = BudgetPlannerServiceMock()
    mock.suggestionsDelayNanos = 150_000_000
    mock.suggestionsResult = .success(
      ReportSuggestionsResponse(
        generatedAt: "2026-04-08T10:00:00Z",
        suggestions: [
          ReportSuggestionResponse(
            id: "overspend-2026-04-01-12",
            title: "Spending exceeded plan",
            message: "You spent 12% above plan.",
            severity: .medium,
            category: .overspend,
            monthStart: "2026-04-01",
            recommendedSavings: 120,
            detailPayload: [:]
          )
        ]
      )
    )

    let viewModel = await MainActor.run {
      BudgetPlannerViewModel(monthlySnapshots: [], activities: [], expensesService: mock)
    }

    let loadingTask = Task { await viewModel.load(force: true) }
    try? await Task.sleep(nanoseconds: 30_000_000)

    await MainActor.run {
      XCTAssertTrue(viewModel.isSuggestionsLoading)
    }

    await loadingTask.value

    await MainActor.run {
      XCTAssertFalse(viewModel.isSuggestionsLoading)
      XCTAssertEqual(viewModel.topReportSuggestion?.id, "overspend-2026-04-01-12")
      XCTAssertFalse(viewModel.suggestionsUnavailable)
    }
  }

  func testLoadUsesUnavailableFallbackWhenSuggestionsFail() async {
    let mock = BudgetPlannerServiceMock()
    mock.suggestionsResult = .failure(MockPlannerError.notConfigured)

    let viewModel = await MainActor.run {
      BudgetPlannerViewModel(monthlySnapshots: [], activities: [], expensesService: mock)
    }

    await viewModel.load(force: true)

    await MainActor.run {
      XCTAssertTrue(viewModel.suggestionsUnavailable)
      XCTAssertNil(viewModel.topReportSuggestion)
    }
  }

  func testDismissSuggestionRemovesSuggestionAndCallsService() async {
    let mock = BudgetPlannerServiceMock()
    mock.suggestionsResult = .success(
      ReportSuggestionsResponse(
        generatedAt: "2026-04-08T10:00:00Z",
        suggestions: [
          ReportSuggestionResponse(
            id: "unplanned-2026-04-01-300",
            title: "High unplanned spend",
            message: "Unplanned spending is high.",
            severity: .high,
            category: .unplannedSpend,
            monthStart: "2026-04-01",
            recommendedSavings: 150,
            detailPayload: [:]
          )
        ]
      )
    )

    let viewModel = await MainActor.run {
      BudgetPlannerViewModel(monthlySnapshots: [], activities: [], expensesService: mock)
    }

    await viewModel.load(force: true)
    guard let suggestion = await MainActor.run(body: { viewModel.topReportSuggestion }) else {
      XCTFail("Expected suggestion")
      return
    }

    await MainActor.run {
      viewModel.dismissSuggestion(suggestion)
    }
    try? await Task.sleep(nanoseconds: 30_000_000)

    await MainActor.run {
      XCTAssertNil(viewModel.topReportSuggestion)
      XCTAssertEqual(mock.dismissedSuggestionIds, [suggestion.id])
    }
  }

  func testAddOrUpdatePlanItemCreatesSnapshotWhenMissingAndPersistsZeroAmount() async {
    let mock = BudgetPlannerServiceMock()
    let createdSnapshotID = "11111111-1111-1111-1111-111111111111"
    mock.createSnapshotResult = .success(
      BudgetSnapshotResponse(
        id: createdSnapshotID,
        monthStart: "2026-06-01",
        netSalary: 3200,
        targetShares: [
          BudgetPillar.fundamentals.rawValue: 0.5,
          BudgetPillar.futureYou.rawValue: 0.2,
          BudgetPillar.fun.rawValue: 0.3,
        ]
      )
    )
    mock.createPlanItemResult = .success(
      BudgetPlanItemResponse(
        id: UUID().uuidString,
        snapshotId: createdSnapshotID,
        title: "Rent",
        plannedAmount: 0,
        pillar: .fundamentals,
        splitMode: .personal,
        userSharePercent: 100,
        createdAt: nil,
        updatedAt: nil
      )
    )

    let viewModel = await MainActor.run {
      BudgetPlannerViewModel(monthlySnapshots: [], activities: [], expensesService: mock)
    }

    await MainActor.run {
      viewModel.selectMonth(makeMonth(2026, 6))
      viewModel.addOrUpdatePlanItem(
        BudgetPlanItemDraft(
          title: "Rent",
          plannedAmount: 0,
          pillar: .fundamentals
        )
      )
    }

    for _ in 0..<60 where mock.createPlanItemRequests.isEmpty {
      try? await Task.sleep(nanoseconds: 20_000_000)
    }

    let expectedMonthStart = formattedDayString(makeMonth(2026, 6))
    XCTAssertEqual(mock.createBudgetSnapshotRequests.count, 1)
    XCTAssertEqual(mock.createBudgetSnapshotRequests.first?.monthStart, expectedMonthStart)
    XCTAssertEqual(mock.createPlanItemRequests.count, 1)
    XCTAssertEqual(mock.createPlanItemRequests.first?.snapshotId, createdSnapshotID)
    XCTAssertEqual(mock.createPlanItemRequests.first?.plannedAmount ?? -1, 0, accuracy: 0.001)
    XCTAssertEqual(mock.createPlanItemRequests.first?.title, "Rent")
  }

  func testRecordExpenseInAnotherMonthSwitchesSelectedMonth() async {
    let mock = BudgetPlannerServiceMock()
    mock.createExpenseResult = .success(
      ExpenseResponse(
        id: "11111111-1111-4111-8111-111111111111",
        title: "Coffee",
        amount: 6,
        pillar: .fun,
        occurredOn: "2026-05-12",
        linkedPlanItemId: nil,
        splitMode: .personal,
        userSharePercent: 100,
        createdAt: nil,
        updatedAt: nil
      )
    )

    let april = makeMonth(2026, 4)
    let mayDate = makeDate(2026, 5, 12)
    let viewModel = await MainActor.run {
      BudgetPlannerViewModel(
        monthlySnapshots: [MonthlyBudgetSnapshot(monthStart: april, netSalary: 3000, items: [])],
        activities: [],
        expensesService: mock
      )
    }

    let didSave = await viewModel.recordExpenseAndWait(
      BudgetActivityDraft(
        title: "Coffee",
        amount: 6,
        pillar: .fun,
        occurredOn: mayDate
      )
    )

    await MainActor.run {
      XCTAssertTrue(didSave)
      XCTAssertEqual(viewModel.selectedMonthStart, makeMonth(2026, 5))
    }
    XCTAssertEqual(mock.createExpenseRequests.count, 1)
    XCTAssertEqual(mock.createExpenseRequests.first?.occurredOn, formattedDayString(mayDate))
    XCTAssertEqual(mock.createExpenseRequests.first?.title, "Coffee")
  }

  func testRecordExpenseInMonthWithoutSnapshotDoesNotCreateLocalSnapshotPlaceholder() async {
    let mock = BudgetPlannerServiceMock()
    mock.createExpenseResult = .success(
      ExpenseResponse(
        id: "22222222-2222-4222-8222-222222222222",
        title: "Food",
        amount: 50,
        pillar: .fun,
        occurredOn: "2026-05-08",
        linkedPlanItemId: nil,
        splitMode: .personal,
        userSharePercent: 100,
        createdAt: nil,
        updatedAt: nil
      )
    )
    mock.expensesResult = .success(
      [
        ExpenseResponse(
          id: "22222222-2222-4222-8222-222222222222",
          title: "Food",
          amount: 50,
          pillar: .fun,
          occurredOn: "2026-05-08",
          linkedPlanItemId: nil,
          splitMode: .personal,
          userSharePercent: 100,
          createdAt: nil,
          updatedAt: nil
        )
      ]
    )

    let april = makeMonth(2026, 4)
    let mayDate = makeDate(2026, 5, 8)
    let viewModel = await MainActor.run {
      BudgetPlannerViewModel(
        monthlySnapshots: [MonthlyBudgetSnapshot(monthStart: april, netSalary: 2050, items: [])],
        activities: [],
        expensesService: mock
      )
    }

    let didSave = await viewModel.recordExpenseAndWait(
      BudgetActivityDraft(
        title: "Food",
        amount: 50,
        pillar: .fun,
        occurredOn: mayDate
      )
    )

    await MainActor.run {
      XCTAssertTrue(didSave)
      XCTAssertEqual(viewModel.selectedMonthStart, makeMonth(2026, 5))
      XCTAssertNil(viewModel.selectedMonthSnapshot)
      XCTAssertEqual(viewModel.selectedMonthActualTotal, 50, accuracy: 0.001)
    }
  }

  func testLoadFallsBackToLocalSummariesWhenReportEndpointsReturnEmpty() async {
    let mock = BudgetPlannerServiceMock()
    mock.monthlyReportsResult = .success([])
    mock.yearlyReportsResult = .success([])
    mock.expensesResult = .success(
      [
        ExpenseResponse(
          id: "33333333-3333-4333-8333-333333333333",
          title: "Groceries",
          amount: 120,
          pillar: .fundamentals,
          occurredOn: "2026-04-08",
          linkedPlanItemId: nil,
          splitMode: .personal,
          userSharePercent: 100,
          createdAt: nil,
          updatedAt: nil
        )
      ]
    )

    let viewModel = await MainActor.run {
      BudgetPlannerViewModel(monthlySnapshots: [], activities: [], expensesService: mock)
    }

    await viewModel.load(force: true)

    await MainActor.run {
      XCTAssertFalse(viewModel.selectedYearSummaries.isEmpty)
      XCTAssertEqual(viewModel.selectedYearActualTotal, 120, accuracy: 0.001)
      XCTAssertEqual(viewModel.selectedMonthActualTotal, 120, accuracy: 0.001)
    }
  }

  func testForceLoadQueuesOneFollowUpReloadWhenCalledDuringLoad() async {
    let mock = BudgetPlannerServiceMock()
    mock.getSnapshotsDelayNanos = 150_000_000

    let viewModel = await MainActor.run {
      BudgetPlannerViewModel(monthlySnapshots: [], activities: [], expensesService: mock)
    }

    let firstLoadTask = Task {
      await viewModel.load(force: true)
    }
    try? await Task.sleep(nanoseconds: 30_000_000)

    await viewModel.load(force: true)
    await firstLoadTask.value

    XCTAssertEqual(mock.getSnapshotsCallCount, 2)
  }

  func testBeginPlannedItemDraftAddsPlaceholderAndCancelRemovesIt() async {
    let mock = BudgetPlannerServiceMock()
    mock.createSnapshotResult = .success(
      BudgetSnapshotResponse(
        id: "A1BF8A69-5CF6-49E4-B291-6E920B34E7DE",
        monthStart: "2026-06-01",
        netSalary: 3200,
        targetShares: [
          BudgetPillar.fundamentals.rawValue: 0.5,
          BudgetPillar.futureYou.rawValue: 0.2,
          BudgetPillar.fun.rawValue: 0.3,
        ]
      )
    )

    let viewModel = await MainActor.run {
      BudgetPlannerViewModel(monthlySnapshots: [], activities: [], expensesService: mock)
    }

    await MainActor.run {
      viewModel.selectMonth(makeMonth(2026, 6))
    }
    let resolvedDraft = await viewModel.beginPlannedItemDraft(pillar: .fundamentals)

    await MainActor.run {
      guard let resolvedDraft else {
        XCTFail("Expected a draft")
        return
      }
      XCTAssertEqual(viewModel.items(for: .fundamentals).count, 1)
      XCTAssertEqual(viewModel.items(for: .fundamentals).first?.plannedAmount ?? -1, 0, accuracy: 0.001)
      viewModel.cancelPlanItemDraft(resolvedDraft)
      XCTAssertTrue(viewModel.items(for: .fundamentals).isEmpty)
    }
  }

  private func makeMonth(_ year: Int, _ month: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .now
  }

  private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
  }

  private func formattedDayString(_ date: Date) -> String {
    dayFormatter.string(from: date)
  }
}

private final class BudgetPlannerServiceMock: ExpensesServicing {
  var snapshotsResult: Result<[BudgetSnapshotResponse], Error> = .success(
    [
      BudgetSnapshotResponse(
        id: "6CC8C5FE-39A5-4E53-94B4-4BE6A7A66A7D",
        monthStart: "2026-04-01",
        netSalary: 3000,
        targetShares: [
          BudgetPillar.fundamentals.rawValue: 0.5,
          BudgetPillar.futureYou.rawValue: 0.2,
          BudgetPillar.fun.rawValue: 0.3,
        ],
        createdAt: nil,
        updatedAt: nil
      )
    ]
  )
  var itemsResult: Result<[BudgetPlanItemResponse], Error> = .success([])
  var expensesResult: Result<[ExpenseResponse], Error> = .success([])
  var monthlyReportsResult: Result<[BudgetMonthSummaryResponse], Error> = .success(
    [
      BudgetMonthSummaryResponse(
        monthStart: "2026-04-01",
        planned: 1000,
        actual: 900,
        salary: 3000,
        pillarActuals: [:],
        pillarPlans: [:]
      )
    ]
  )
  var yearlyReportsResult: Result<[BudgetYearSummaryResponse], Error> = .success([])
  var createSnapshotResult: Result<BudgetSnapshotResponse, Error> = .failure(MockPlannerError.notConfigured)
  var updateSnapshotResult: Result<BudgetSnapshotResponse, Error> = .failure(MockPlannerError.notConfigured)
  var createPlanItemResult: Result<BudgetPlanItemResponse, Error> = .failure(MockPlannerError.notConfigured)
  var createExpenseResult: Result<ExpenseResponse, Error> = .failure(MockPlannerError.notConfigured)

  var suggestionsResult: Result<ReportSuggestionsResponse, Error> = .success(
    ReportSuggestionsResponse(generatedAt: "", suggestions: [])
  )
  var getSnapshotsDelayNanos: UInt64 = 0
  var suggestionsDelayNanos: UInt64 = 0
  var getSnapshotsCallCount = 0
  var createBudgetSnapshotRequests: [BudgetSnapshotRequest] = []
  var updateSnapshotRequests: [BudgetSnapshotRequest] = []
  var createPlanItemRequests: [BudgetPlanItemRequest] = []
  var createExpenseRequests: [ExpenseRequest] = []
  var dismissedSuggestionIds: [String] = []

  func getHouseholdPartner() async throws -> HouseholdPartnerProfileResponse {
    HouseholdPartnerProfileResponse(displayName: "Partner")
  }

  func updateHouseholdPartner(payload _: HouseholdPartnerProfileRequest) async throws -> HouseholdPartnerProfileResponse {
    HouseholdPartnerProfileResponse(displayName: "Partner")
  }

  func getSnapshots(year _: Int?, month _: Int?) async throws -> [BudgetSnapshotResponse] {
    getSnapshotsCallCount += 1
    if getSnapshotsDelayNanos > 0 {
      try? await Task.sleep(nanoseconds: getSnapshotsDelayNanos)
    }
    return try snapshotsResult.get()
  }

  func createBudgetSnapshot(request: BudgetSnapshotRequest) async throws -> BudgetSnapshotResponse {
    createBudgetSnapshotRequests.append(request)
    return try createSnapshotResult.get()
  }

  func updateSnapshot(snapshotId _: String, payload: BudgetSnapshotRequest) async throws -> BudgetSnapshotResponse {
    updateSnapshotRequests.append(payload)
    return try updateSnapshotResult.get()
  }

  func deleteSnapshot(snapshotId _: String) async throws {}

  func getSnapshotItems(snapshotId _: String) async throws -> [BudgetPlanItemResponse] { [] }

  func getAllPlanItems() async throws -> [BudgetPlanItemResponse] {
    try itemsResult.get()
  }

  func createPlanItem(payload: BudgetPlanItemRequest) async throws -> BudgetPlanItemResponse {
    createPlanItemRequests.append(payload)
    return try createPlanItemResult.get()
  }

  func updatePlanItem(itemId _: String, payload _: BudgetPlanItemRequest) async throws -> BudgetPlanItemResponse {
    throw MockPlannerError.notConfigured
  }

  func deletePlanItem(itemId _: String) async throws {}

  func getExpenses(from _: String?, to _: String?) async throws -> [ExpenseResponse] {
    try expensesResult.get()
  }

  func createExpense(request: ExpenseRequest) async throws -> ExpenseResponse {
    createExpenseRequests.append(request)
    return try createExpenseResult.get()
  }

  func updateExpense(expenseId _: String, payload _: ExpenseRequest) async throws -> ExpenseResponse {
    throw MockPlannerError.notConfigured
  }

  func deleteExpense(expenseId _: String) async throws {}

  func getReportsOverview(from _: String?, to _: String?) async throws -> ReportsOverviewResponse {
    ReportsOverviewResponse(
      generatedAt: "",
      portfolioStatistics: ImportedStocksStatisticsDTO(
        totalPositions: 0,
        totalMarketValue: 0,
        totalCostBasis: 0,
        totalUnrealizedPnl: 0,
        totalRealizedPnl: 0,
        stockSummaries: [],
        stockAllocations: [],
        sectorAllocations: [],
        calendarPerformance: []
      ),
      monthlySummaries: [],
      yearlySummaries: [],
      latestMonthSummary: nil,
      latestPillarSummaries: [],
      cashFlow: []
    )
  }

  func getMonthlyExpenseReports(from _: String?, to _: String?) async throws -> [BudgetMonthSummaryResponse] {
    try monthlyReportsResult.get()
  }

  func getYearlyExpenseReports(from _: String?, to _: String?) async throws -> [BudgetYearSummaryResponse] {
    try yearlyReportsResult.get()
  }

  func getReportSuggestions(from _: String?, to _: String?) async throws -> ReportSuggestionsResponse {
    if suggestionsDelayNanos > 0 {
      try? await Task.sleep(nanoseconds: suggestionsDelayNanos)
    }
    return try suggestionsResult.get()
  }

  func dismissReportSuggestion(id: String) async throws {
    dismissedSuggestionIds.append(id)
  }
}

private enum MockPlannerError: LocalizedError {
  case notConfigured

  var errorDescription: String? { "Not configured." }
}
