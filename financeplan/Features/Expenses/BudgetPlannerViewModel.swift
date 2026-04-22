import Combine
import Foundation
import SwiftData
import OSLog
import Factory
import StockPlanShared

@MainActor
final class BudgetPlannerViewModel: ObservableObject, BudgetPlannerStoreProtocol, ActivityTimelineStoreProtocol {
  @Published private(set) var monthlySnapshots: [MonthlyBudgetSnapshot] = []
  @Published private(set) var activities: [BudgetActivity] = []
  @Published private(set) var monthlySummaries: [BudgetMonthSummary] = []
  @Published private(set) var yearlySummaries: [BudgetYearSummary] = []
  @Published private(set) var reportSuggestions: [ReportSuggestionResponse] = []
  @Published private(set) var categories: [ExpenseCategoryResponse] = []
  @Published private(set) var recurringTemplates: [RecurringTemplateResponse] = []
  @Published private(set) var isSuggestionsLoading = false
  @Published private(set) var suggestionsUnavailable = false
  @Published private(set) var partnerDisplayName: String = "Partner"
  @Published var selectedMonthStart: Date = .now
  @Published var isLoading = false
  @Published var errorMessage: String?

  private let calendar: Calendar
  private let expensesService: any ExpensesServicing
  private var hasLoadedOnce = false
  private var pendingForceReload = false
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
    category: "BudgetPlannerViewModel"
  )

  private var ownerUserId: String {
    LocalCacheScope.currentOwnerUserId
  }

  private let dateFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd"
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone.current
      return formatter
  }()

  init() {
    self.calendar = Calendar(identifier: .gregorian)
    self.expensesService = Container.shared.expensesService()
    self.selectedMonthStart = self.calendar.startOfMonth(for: .now)
  }

  init(
    monthlySnapshots: [MonthlyBudgetSnapshot],
    activities: [BudgetActivity],
    expensesService: any ExpensesServicing = Container.shared.expensesService()
  ) {
    let calendar = Calendar(identifier: .gregorian)
    self.calendar = calendar
    self.expensesService = expensesService
    self.monthlySnapshots = monthlySnapshots.sorted { $0.monthStart < $1.monthStart }
    self.activities = activities.sorted { $0.occurredOn > $1.occurredOn }
    let availableMonths = Self.makeAvailableMonths(
      snapshots: self.monthlySnapshots,
      activities: self.activities,
      calendar: calendar
    )
    self.selectedMonthStart = availableMonths.first ?? calendar.startOfMonth(for: .now)
    self.monthlySummaries = Self.makeLocalMonthlySummaries(
      snapshots: self.monthlySnapshots,
      activities: self.activities,
      calendar: calendar
    )
    self.yearlySummaries = Self.makeLocalYearlySummaries(from: self.monthlySummaries, calendar: calendar)
  }

  func load(force: Bool = false) async {
      if !force, hasLoadedOnce { return }
      if isLoading {
          if force {
              pendingForceReload = true
          }
          return
      }

      isLoading = true
      isSuggestionsLoading = true
      suggestionsUnavailable = false
      errorMessage = nil

      do {
          let partner = try? await expensesService.getHouseholdPartner()
          if let partner {
              self.partnerDisplayName = partner.displayName ?? "Partner"
          }

          // Trigger sync in the background or wait if forced
          if force || !hasLoadedOnce {
              try? await ExpensesSyncManager.shared.pullLatestData(from: expensesService)
          }

          // Load from SwiftData
          let context = ExpensesSyncManager.shared.context
          let currentOwnerUserId = ownerUserId
          let fetchedSnapshots = try context.fetch(FetchDescriptor<LocalBudgetSnapshot>())
            .filter { LocalCacheScope.isOwnedByCurrentUser($0.ownerUserId, currentUserId: currentOwnerUserId) }
          let fetchedItems = try context.fetch(FetchDescriptor<LocalBudgetPlanItem>())
            .filter { LocalCacheScope.isOwnedByCurrentUser($0.ownerUserId, currentUserId: currentOwnerUserId) }
          let fetchedExpenses = try context.fetch(FetchDescriptor<LocalExpense>())
            .filter { LocalCacheScope.isOwnedByCurrentUser($0.ownerUserId, currentUserId: currentOwnerUserId) }
          let fetchedCategories = try context.fetch(FetchDescriptor<LocalExpenseCategory>())
            .filter { LocalCacheScope.isOwnedByCurrentUser($0.ownerUserId, currentUserId: currentOwnerUserId) }
          let fetchedRecurringTemplates = try context.fetch(FetchDescriptor<LocalRecurringTemplate>())
            .filter { LocalCacheScope.isOwnedByCurrentUser($0.ownerUserId, currentUserId: currentOwnerUserId) }

          self.categories = fetchedCategories.map { cat in
              ExpenseCategoryResponse(id: cat.id, name: cat.name, pillar: cat.pillar)
          }
          
          self.recurringTemplates = fetchedRecurringTemplates.map { tpl in
              RecurringTemplateResponse(
                  id: tpl.id,
                  title: tpl.title,
                  amount: tpl.amount,
                  pillar: tpl.pillar,
                  categoryId: tpl.categoryId,
                  frequency: tpl.frequency,
                  splitMode: tpl.splitMode,
                  userSharePercent: tpl.userSharePercent
              )
          }

          let itemsBySnapshotId = Dictionary(grouping: fetchedItems, by: \.snapshot?.id.uuidString)

          var newSnapshots = fetchedSnapshots.map { snap -> MonthlyBudgetSnapshot in
              let targetShares = snap.targetShares

              let mappedItems = (itemsBySnapshotId[snap.id.uuidString] ?? []).compactMap { item -> BudgetPlanItem? in
                  let catName = item.categoryId.flatMap { catId in
                      fetchedCategories.first(where: { $0.id == catId })?.name
                  }
                  return BudgetPlanItem(
                    id: item.id,
                    title: item.title,
                    plannedAmount: item.plannedAmount,
                    pillar: item.pillar,
                    categoryId: item.categoryId,
                    categoryName: catName,
                    splitMode: item.splitMode,
                    userSharePercent: item.userSharePercent
                  )
              }

              return MonthlyBudgetSnapshot(
                  id: snap.id,
                  monthStart: snap.monthStart,
                  netSalary: snap.netSalary,
                  targetShares: targetShares,
                  items: mappedItems
              )
          }

          let newActivities = fetchedExpenses.map { exp -> BudgetActivity in
              BudgetActivity(
                id: exp.id,
                title: exp.title,
                amount: exp.amount,
                pillar: exp.pillar,
                occurredOn: exp.occurredOn,
                linkedPlanItemID: exp.linkedPlanItemId,
                splitMode: exp.splitMode,
                userSharePercent: exp.userSharePercent
              )
          }

          newSnapshots.sort { $0.monthStart < $1.monthStart }
          self.monthlySnapshots = newSnapshots
          self.activities = newActivities.sorted { $0.occurredOn > $1.occurredOn }

          let localMonthlySummaries = Self.makeLocalMonthlySummaries(
            snapshots: newSnapshots,
            activities: self.activities,
            calendar: self.calendar
          )
          
          let fetchedMonthlyReports = (try? await expensesService.getMonthlyExpenseReports(from: nil, to: nil)) ?? []
          let fetchedMonthlySummaries = fetchedMonthlyReports.compactMap(mapMonthSummary)
          
          self.monthlySummaries = Self.mergeMonthlySummaries(
            preferred: fetchedMonthlySummaries.isEmpty ? localMonthlySummaries : fetchedMonthlySummaries,
            fallback: localMonthlySummaries,
            calendar: self.calendar
          )

          let fetchedYearlyReports = (try? await expensesService.getYearlyExpenseReports(from: nil, to: nil)) ?? []
          let fetchedYearlySummaries = fetchedYearlyReports.map { report in
              BudgetYearSummary(
                  year: report.year,
                  planned: report.planned,
                  actual: report.actual,
                  salary: report.salary,
                  myPlanned: report.myPlanned,
                  partnerPlanned: report.partnerPlanned,
                  myActual: report.myActual,
                  partnerActual: report.partnerActual
              )
          }
          let localYearlySummaries = Self.makeLocalYearlySummaries(
            from: self.monthlySummaries,
            calendar: self.calendar
          )
          self.yearlySummaries = Self.mergeYearlySummaries(
            preferred: fetchedYearlySummaries.isEmpty ? localYearlySummaries : fetchedYearlySummaries,
            fallback: localYearlySummaries
          )

          let availableMonths = Self.makeAvailableMonths(
            snapshots: newSnapshots,
            activities: self.activities,
            calendar: self.calendar
          )
          if let latest = availableMonths.first,
             !availableMonths.contains(where: { self.calendar.isDate($0, equalTo: self.selectedMonthStart, toGranularity: .month) }) {
              self.selectedMonthStart = latest
          }

          do {
              let suggestionsResponse = try await expensesService.getReportSuggestions(from: nil, to: nil)
              self.reportSuggestions = suggestionsResponse.suggestions
              self.suggestionsUnavailable = false
          } catch {
              self.reportSuggestions = []
              self.suggestionsUnavailable = true
          }

          hasLoadedOnce = true
      } catch {
          self.errorMessage = "Could not load planner data: \(error.localizedDescription)"
      }

      isLoading = false
      isSuggestionsLoading = false

      if pendingForceReload {
          pendingForceReload = false
          await load(force: true)
      }
      
      // Attempt to push offline actions
      await ExpensesSyncManager.shared.pushPendingActions(to: expensesService)
  }

  var topReportSuggestion: ReportSuggestionResponse? {
    reportSuggestions.first
  }

  var recentExpenseActivities: [BudgetActivity] {
    activities
      .sorted { $0.occurredOn > $1.occurredOn }
      .prefix(10)
      .map { $0 }
  }

  func dismissSuggestion(_ suggestion: ReportSuggestionResponse) {
      let previous = reportSuggestions
      reportSuggestions.removeAll { $0.id == suggestion.id }
      Task {
          do {
              try await expensesService.dismissReportSuggestion(id: suggestion.id)
          } catch {
              self.reportSuggestions = previous
              self.suggestionsUnavailable = true
          }
      }
  }

  func beginPlannedItemDraft(pillar: BudgetPillar) async -> BudgetPlanItemDraft? {
      do {
          _ = try await ensureSnapshotExistsForSelectedMonth()
          guard let selectedMonthSnapshotIndex else {
            throw NSError(
              domain: "BudgetPlannerViewModel",
              code: 1002,
              userInfo: [NSLocalizedDescriptionKey: "Could not resolve selected month snapshot."]
            )
          }
          let placeholderItem = BudgetPlanItem(
            title: "New item",
            plannedAmount: 0,
            pillar: pillar,
            splitMode: .personal,
            userSharePercent: 100
          )
          monthlySnapshots[selectedMonthSnapshotIndex].items.append(placeholderItem)
          monthlySnapshots[selectedMonthSnapshotIndex].items.sort {
            if $0.pillar == $1.pillar {
              return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.pillar.rawValue < $1.pillar.rawValue
          }

          logger.debug("Planned item draft started for pillar=\(pillar.rawValue, privacy: .public)")
          return BudgetPlanItemDraft(
            itemID: nil,
            placeholderItemID: placeholderItem.id,
            title: "",
            plannedAmount: 0,
            pillar: pillar,
            splitMode: .personal,
            userSharePercent: 100
          )
      } catch {
          self.errorMessage = "Could not start a new planned item: \(error.localizedDescription)"
          logger.error("Failed to start planned item draft: \(error.localizedDescription, privacy: .public)")
          return nil
      }
  }

  func cancelPlanItemDraft(_ draft: BudgetPlanItemDraft) {
      guard let placeholderItemID = draft.placeholderItemID else { return }
      for index in monthlySnapshots.indices {
          monthlySnapshots[index].items.removeAll { $0.id == placeholderItemID }
      }
  }

  var availableMonths: [Date] {
    Self.makeAvailableMonths(
      snapshots: monthlySnapshots,
      activities: activities,
      calendar: calendar
    )
  }

  var availableYears: [Int] {
    Array(
      Set(
        availableMonths.map { monthStart in
          calendar.component(.year, from: monthStart)
        }
      )
    )
    .sorted(by: >)
  }

  var selectedYear: Int {
    calendar.component(.year, from: selectedMonthStart)
  }

  var selectedMonthSnapshot: MonthlyBudgetSnapshot? {
    guard let index = selectedMonthSnapshotIndex else { return nil }
    return monthlySnapshots[index]
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

  var selectedMonthPillars: [BudgetPillar] {
    guard let snapshot = snapshot(for: selectedMonthStart) else {
      return BudgetPillar.standardPillars
    }
    return Self.resolvedPillars(snapshot: snapshot, activities: activitiesForMonth(selectedMonthStart))
  }

  var preferredInitialPillar: BudgetPillar {
    selectedMonthPillars.first ?? .fundamentals
  }

  func categories(for pillar: BudgetPillar) -> [ExpenseCategoryResponse] {
    categories.filter { $0.pillar == nil || $0.pillar == pillar }
  }

  func saveRecurringTemplate(_ request: RecurringTemplateRequest, templateId: String? = nil) {
    Task {
      do {
        if let templateId {
          let updated = try await expensesService.updateRecurringTemplate(templateId: templateId, payload: request)
          if let idx = recurringTemplates.firstIndex(where: { $0.id == templateId }) {
            recurringTemplates[idx] = updated
          }
        } else {
          let created = try await expensesService.createRecurringTemplate(payload: request)
          recurringTemplates.append(created)
        }
      } catch {
        self.errorMessage = error.localizedDescription
      }
    }
  }

  func deleteRecurringTemplate(_ templateId: String) {
    recurringTemplates.removeAll { $0.id == templateId }
    Task {
      do {
        try await expensesService.deleteRecurringTemplate(templateId: templateId)
      } catch {
        self.errorMessage = error.localizedDescription
        await load(force: true)
      }
    }
  }

  func draftFromRecurringTemplate(_ template: RecurringTemplateResponse) -> BudgetActivityDraft {
    BudgetActivityDraft(
      title: template.title,
      amount: template.amount,
      pillar: template.pillar,
      occurredOn: Date(),
      categoryId: template.categoryId,
      splitMode: template.splitMode,
      userSharePercent: template.userSharePercent
    )
  }

  var selectedMonthSummaries: [PillarPlanningSummary] {
    selectedMonthPillars.map { pillar in
      PillarPlanningSummary(
        pillar: pillar,
        targetAmount: targetAmount(for: pillar, monthStart: selectedMonthStart),
        plannedAmount: plannedTotal(for: pillar, monthStart: selectedMonthStart),
        actualAmount: actualTotal(for: pillar, monthStart: selectedMonthStart),
        unplannedActualAmount: unplannedActual(for: pillar, monthStart: selectedMonthStart)
      )
    }
  }
  
  func previousMonthPillarActual(for pillar: BudgetPillar) -> Double? {
    guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonthStart) else {
      return nil
    }
    let previousMonthStart = calendar.startOfMonth(for: previousMonth)
    return actualTotal(for: pillar, monthStart: previousMonthStart)
  }

  var selectedMonthPlannedTotal: Double {
    selectedMonthSnapshot?.items.reduce(0) { $0 + $1.plannedAmount } ?? 0
  }

  var selectedMonthActualTotal: Double {
    actualTotal(for: selectedMonthStart)
  }

  var selectedMonthMyPlannedTotal: Double {
    selectedMonthSnapshot?.items.reduce(0) { $0 + myPortion(of: $1.plannedAmount, splitMode: $1.splitMode, userSharePercent: $1.userSharePercent) } ?? 0
  }

  var selectedMonthPartnerPlannedTotal: Double {
    selectedMonthSnapshot?.items.reduce(0) { $0 + partnerPortion(of: $1.plannedAmount, splitMode: $1.splitMode, userSharePercent: $1.userSharePercent) } ?? 0
  }

  var selectedMonthMyActualTotal: Double {
    selectedMonthActivities.reduce(0) { $0 + myPortion(of: $1.amount, splitMode: $1.splitMode, userSharePercent: $1.userSharePercent) }
  }

  var selectedMonthPartnerActualTotal: Double {
    selectedMonthActivities.reduce(0) { $0 + partnerPortion(of: $1.amount, splitMode: $1.splitMode, userSharePercent: $1.userSharePercent) }
  }

  var selectedMonthRemainingToAllocate: Double {
    (selectedMonthSnapshot?.netSalary ?? 0) - selectedMonthPlannedTotal
  }

  var selectedMonthAvailableAfterPillarPlan: Double {
    selectedMonthRemainingToAllocate
  }

  var selectedMonthLeftAfterSpending: Double {
    (selectedMonthSnapshot?.netSalary ?? 0) - selectedMonthActualTotal
  }

  var selectedMonthDisplayTitle: String {
    selectedMonthStart.formatted(.dateTime.month(.wide).year())
  }

  func selectMonth(_ monthStart: Date) {
    selectedMonthStart = calendar.startOfMonth(for: monthStart)
  }

  func selectYear(_ year: Int) {
    guard let latestMonthInYear = availableMonths.first(where: {
      calendar.component(.year, from: $0) == year
    }) else { return }
    selectedMonthStart = latestMonthInYear
  }

  func createNextMonthPlan() {
    let nextMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonthStart) ?? .now
    let nextMonthStart = calendar.startOfMonth(for: nextMonth)

    guard !monthlySnapshots.contains(where: { calendar.isDate($0.monthStart, equalTo: nextMonthStart, toGranularity: .month) }) else {
      selectedMonthStart = nextMonthStart
      return
    }

    let template = selectedMonthSnapshot ?? monthlySnapshots.last ?? MonthlyBudgetSnapshot(
      monthStart: calendar.startOfMonth(for: selectedMonthStart),
      netSalary: 0,
      targetShares: BudgetPillar.defaultShares,
      items: []
    )
    let newSnapshot = MonthlyBudgetSnapshot(
      id: UUID(),
      monthStart: nextMonthStart,
      netSalary: template.netSalary,
      targetShares: template.targetShares,
      items: template.items.map {
        BudgetPlanItem(
          id: UUID(),
          title: $0.title,
          plannedAmount: $0.plannedAmount,
          pillar: $0.pillar,
          categoryId: $0.categoryId,
          categoryName: $0.categoryName,
          splitMode: $0.splitMode,
          userSharePercent: $0.userSharePercent
        )
      }
    )

    monthlySnapshots.append(newSnapshot)
    monthlySnapshots.sort { $0.monthStart < $1.monthStart }
    selectedMonthStart = nextMonthStart

    Task {
        do {
            var stringShares: [String: Double] = [:]
            for (k, v) in template.targetShares { stringShares[k.rawValue] = v }

            let req = BudgetSnapshotRequest(monthStart: self.dayString(from: nextMonthStart), netSalary: template.netSalary, targetShares: stringShares)
            let createdSnap = try await expensesService.createBudgetSnapshot(request: req)

            for item in template.items {
                let itemReq = BudgetPlanItemRequest(
                  snapshotId: createdSnap.id,
                  title: item.title,
                  plannedAmount: item.plannedAmount,
                  pillar: item.pillar,
                  categoryId: item.categoryId,
                  splitMode: item.splitMode,
                  userSharePercent: item.userSharePercent
                )
                _ = try await expensesService.createPlanItem(payload: itemReq)
            }
            await load(force: true)
            notifyDataDidChange()
        } catch {
            self.errorMessage = error.localizedDescription
            await load(force: true)
        }
    }
  }

  func deleteCurrentSnapshot() {
      guard let selectedMonthSnapshotIndex else {
          errorMessage = "No monthly plan exists for the selected month."
          return
      }

      let snapshotId = monthlySnapshots[selectedMonthSnapshotIndex].id
      monthlySnapshots.remove(at: selectedMonthSnapshotIndex)

      if monthlySnapshots.isEmpty {
          selectedMonthStart = calendar.startOfMonth(for: .now)
      } else {
          selectedMonthStart = monthlySnapshots.last?.monthStart ?? calendar.startOfMonth(for: .now)
      }
      refreshDerivedSummariesFromLocal()

      Task {
          do {
              try await expensesService.deleteSnapshot(snapshotId: snapshotId.uuidString)
              notifyDataDidChange()
          } catch {
              self.errorMessage = error.localizedDescription
              await load(force: true)
          }
      }
  }

  func updateNetSalary(_ amount: Double) {
    let newAmount = max(amount, 0)

    Task {
        do {
            let currentSnapshot = try await ensureSnapshotExistsForSelectedMonth()
            var stringShares: [String: Double] = [:]
            for (k, v) in currentSnapshot.targetShares { stringShares[k.rawValue] = v }
            let req = BudgetSnapshotRequest(
              monthStart: self.dayString(from: currentSnapshot.monthStart),
              netSalary: newAmount,
              targetShares: stringShares
            )
            let updated = try await expensesService.updateSnapshot(
              snapshotId: currentSnapshot.id.uuidString,
              payload: req
            )

            let mapped = mapSnapshotResponse(updated, existingItems: currentSnapshot.items)
            upsertSnapshot(mapped)
            refreshDerivedSummariesFromLocal()
            notifyDataDidChange()
        } catch {
            self.errorMessage = error.localizedDescription
            await load(force: true)
        }
    }
  }

  func updateTargetShares(_ shares: [BudgetPillar: Double]) {
    let normalized = normalizeShares(shares)

    Task {
        do {
            let currentSnapshot = try await ensureSnapshotExistsForSelectedMonth()
            var stringShares: [String: Double] = [:]
            for (k, v) in normalized { stringShares[k.rawValue] = v }
            let req = BudgetSnapshotRequest(
              monthStart: self.dayString(from: currentSnapshot.monthStart),
              netSalary: currentSnapshot.netSalary,
              targetShares: stringShares
            )
            let updated = try await expensesService.updateSnapshot(
              snapshotId: currentSnapshot.id.uuidString,
              payload: req
            )

            let mapped = mapSnapshotResponse(updated, existingItems: currentSnapshot.items)
            upsertSnapshot(mapped)
            refreshDerivedSummariesFromLocal()
            notifyDataDidChange()
        } catch {
            self.errorMessage = error.localizedDescription
            await load(force: true)
        }
    }
  }

  func updatePartnerDisplayName(_ name: String?) {
    Task {
      do {
        let partner = try await expensesService.updateHouseholdPartner(
          payload: HouseholdPartnerProfileRequest(displayName: name)
        )
        self.partnerDisplayName = partner.displayName ?? "Partner"
      } catch {
        self.errorMessage = error.localizedDescription
        await load(force: true)
      }
    }
  }

  func addOrUpdatePlanItem(_ draft: BudgetPlanItemDraft) {
    let title = String(draft.title).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else {
      errorMessage = "Planned item needs a name."
      return
    }

    let plannedAmount = max(draft.plannedAmount, 0)
    Task {
      do {
        let snapshot = try await ensureSnapshotExistsForSelectedMonth()
        let targetSnapshotID = snapshot.id
        guard let selectedMonthSnapshotIndex = monthlySnapshots.firstIndex(where: { $0.id == targetSnapshotID }) else {
          throw NSError(
            domain: "BudgetPlannerViewModel",
            code: 1003,
            userInfo: [NSLocalizedDescriptionKey: "Could not resolve selected month snapshot."]
          )
        }
        let snapshotId = snapshot.id

        if let placeholderItemID = draft.placeholderItemID {
          cancelPlanItemDraft(draft)
          logger.debug("Removed placeholder planned item id=\(placeholderItemID.uuidString, privacy: .public)")
        }

        if let itemID = draft.itemID {
          logger.debug("Attempting plan item update id=\(itemID.uuidString, privacy: .public) title=\(title, privacy: .public)")
          let req = BudgetPlanItemRequest(
            snapshotId: snapshotId.uuidString,
            title: title,
            plannedAmount: plannedAmount,
            pillar: draft.pillar,
            categoryId: draft.categoryId,
            splitMode: draft.splitMode,
            userSharePercent: draft.userSharePercent
          )
          let updated = try await expensesService.updatePlanItem(itemId: itemID.uuidString, payload: req)
          if let mapped = mapPlanItemResponse(updated),
             let snapshotIndex = monthlySnapshots.firstIndex(where: { $0.id == targetSnapshotID }),
             let existingIndex = monthlySnapshots[snapshotIndex].items.firstIndex(where: { $0.id == itemID }) {
            monthlySnapshots[snapshotIndex].items[existingIndex] = mapped
          }
          logger.debug("Plan item update succeeded id=\(itemID.uuidString, privacy: .public)")
        } else {
          logger.debug("Attempting plan item create title=\(title, privacy: .public)")
          let req = BudgetPlanItemRequest(
            snapshotId: snapshotId.uuidString,
            title: title,
            plannedAmount: plannedAmount,
            pillar: draft.pillar,
            categoryId: draft.categoryId,
            splitMode: draft.splitMode,
            userSharePercent: draft.userSharePercent
          )
          let created = try await expensesService.createPlanItem(payload: req)
          if let mapped = mapPlanItemResponse(created) {
            guard let snapshotIndex = monthlySnapshots.firstIndex(where: { $0.id == targetSnapshotID }) else {
              throw NSError(
                domain: "BudgetPlannerViewModel",
                code: 1004,
                userInfo: [NSLocalizedDescriptionKey: "Could not resolve selected month snapshot after create."]
              )
            }
            monthlySnapshots[snapshotIndex].items.removeAll {
              if let placeholderItemID = draft.placeholderItemID {
                return $0.id == placeholderItemID
              }
              return false
            }
            monthlySnapshots[snapshotIndex].items.append(mapped)
          }
          logger.debug("Plan item create succeeded title=\(title, privacy: .public)")
        }

        guard let finalSnapshotIndex = monthlySnapshots.firstIndex(where: { $0.id == targetSnapshotID }) else {
          throw NSError(
            domain: "BudgetPlannerViewModel",
            code: 1005,
            userInfo: [NSLocalizedDescriptionKey: "Could not resolve selected month snapshot after save."]
          )
        }
        monthlySnapshots[finalSnapshotIndex].items.sort {
          if $0.pillar == $1.pillar {
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
          }
          return $0.pillar.rawValue < $1.pillar.rawValue
        }
        refreshDerivedSummariesFromLocal()
        notifyDataDidChange()
      } catch {
        let message = "Could not save planned item: \(error.localizedDescription)"
        self.errorMessage = message
        logger.error("Plan item save failed: \(error.localizedDescription, privacy: .public)")
        await load(force: true)
        self.errorMessage = message
      }
    }
  }

  func removePlanItem(_ itemID: UUID) {
    guard let selectedMonthSnapshot else { return }
    let targetSnapshotID = selectedMonthSnapshot.id
    let removedItems = selectedMonthSnapshot.items
    guard let snapshotIndex = monthlySnapshots.firstIndex(where: { $0.id == targetSnapshotID }) else { return }
    monthlySnapshots[snapshotIndex].items.removeAll { $0.id == itemID }
    refreshDerivedSummariesFromLocal()
    Task {
        do {
            try await expensesService.deletePlanItem(itemId: itemID.uuidString)
            notifyDataDidChange()
        } catch {
            if let rollbackSnapshotIndex = monthlySnapshots.firstIndex(where: { $0.id == targetSnapshotID }) {
              monthlySnapshots[rollbackSnapshotIndex].items = removedItems
            }
            refreshDerivedSummariesFromLocal()
            self.errorMessage = error.localizedDescription
            await load(force: true)
        }
    }
  }

  func recordExpense(_ draft: BudgetActivityDraft) {
    guard let prepared = prepareExpenseForSave(draft) else { return }
    Task {
      _ = await persistExpense(prepared)
    }
  }

  @discardableResult
  func recordExpenseAndWait(_ draft: BudgetActivityDraft) async -> Bool {
    guard let prepared = prepareExpenseForSave(draft) else { return false }
    return await persistExpense(prepared)
  }

  @discardableResult
  func updateExpenseAndWait(expenseID: UUID, _ draft: BudgetActivityDraft) async -> Bool {
    guard let prepared = prepareExpenseForSave(draft) else { return false }
    return await persistExpenseUpdate(expenseID: expenseID, prepared: prepared)
  }

  func removeExpense(_ expenseID: UUID) {
    guard let removedIndex = activities.firstIndex(where: { $0.id == expenseID }) else { return }
    let removedActivity = activities[removedIndex]
    activities.remove(at: removedIndex)
    refreshDerivedSummariesFromLocal()

    Task {
      do {
        try await expensesService.deleteExpense(expenseId: expenseID.uuidString)
        notifyDataDidChange()
      } catch {
        activities.removeAll { $0.id == removedActivity.id }
        activities.insert(removedActivity, at: 0)
        activities.sort { $0.occurredOn > $1.occurredOn }
        refreshDerivedSummariesFromLocal()
        self.errorMessage = "Could not delete expense: \(error.localizedDescription)"
        await load(force: true)
      }
    }
  }

  private func prepareExpenseForSave(_ draft: BudgetActivityDraft) -> (title: String, draft: BudgetActivityDraft)? {
    let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else {
      errorMessage = "Spend entry needs a title."
      return nil
    }

    let activityMonth = calendar.startOfMonth(for: draft.occurredOn)
    selectedMonthStart = activityMonth
    return (title: title, draft: draft)
  }

  private func persistExpense(_ prepared: (title: String, draft: BudgetActivityDraft)) async -> Bool {
    do {
      guard !ownerUserId.isEmpty else {
        errorMessage = "Could not record spend: missing user session."
        return false
      }
      logger.debug(
        "Attempting expense create title=\(prepared.title, privacy: .public) amount=\(prepared.draft.amount, privacy: .public)"
      )
      
      let context = ExpensesSyncManager.shared.context
      let newId = UUID()
      let expense = LocalExpense(
        id: newId,
        ownerUserId: ownerUserId,
        title: prepared.title,
        amount: max(prepared.draft.amount, 0),
        pillar: prepared.draft.pillar,
        occurredOn: prepared.draft.occurredOn,
        linkedPlanItemId: prepared.draft.linkedPlanItemID,
        categoryId: prepared.draft.categoryId,
        splitMode: prepared.draft.splitMode,
        userSharePercent: prepared.draft.userSharePercent,
        foreignAmount: prepared.draft.foreignAmount,
        foreignCurrency: prepared.draft.foreignCurrency,
        exchangeRate: prepared.draft.exchangeRate
      )
      context.insert(expense)
      
      let req = ExpenseRequest(
        title: prepared.title,
        amount: max(prepared.draft.amount, 0),
        pillar: prepared.draft.pillar,
        occurredOn: self.dayString(from: prepared.draft.occurredOn),
        linkedPlanItemId: prepared.draft.linkedPlanItemID?.uuidString,
        categoryId: prepared.draft.categoryId,
        splitMode: prepared.draft.splitMode,
        userSharePercent: prepared.draft.userSharePercent,
        foreignAmount: prepared.draft.foreignAmount,
        foreignCurrency: prepared.draft.foreignCurrency,
        exchangeRate: prepared.draft.exchangeRate
      )
      
      let payload = try? JSONEncoder().encode(req)
      let action = OfflineSyncAction(
        ownerUserId: ownerUserId,
        entityId: newId.uuidString,
        entityType: .expense,
        operationType: .create,
        payloadJSON: payload
      )
      context.insert(action)
      try context.save()
      
      // Update local memory
      let newActivity = BudgetActivity(
          id: newId,
          title: prepared.title,
          amount: max(prepared.draft.amount, 0),
          pillar: prepared.draft.pillar,
          occurredOn: prepared.draft.occurredOn,
          linkedPlanItemID: prepared.draft.linkedPlanItemID,
          splitMode: prepared.draft.splitMode,
          userSharePercent: prepared.draft.userSharePercent,
          foreignAmount: prepared.draft.foreignAmount,
          foreignCurrency: prepared.draft.foreignCurrency,
          exchangeRate: prepared.draft.exchangeRate
      )
      activities.removeAll { $0.id == newActivity.id }
      activities.insert(newActivity, at: 0)
      activities.sort { $0.occurredOn > $1.occurredOn }

      logger.debug("Expense create succeeded locally title=\(prepared.title, privacy: .public)")
      refreshDerivedSummariesFromLocal()
      notifyDataDidChange()
      
      // Trigger sync
      Task { await ExpensesSyncManager.shared.pushPendingActions(to: expensesService) }
      
      return true
    } catch {
      let message = "Could not record spend: \(error.localizedDescription)"
      self.errorMessage = message
      logger.error("Expense create failed locally: \(error.localizedDescription, privacy: .public)")
      return false
    }
  }

  private func persistExpenseUpdate(
    expenseID: UUID,
    prepared: (title: String, draft: BudgetActivityDraft)
  ) async -> Bool {
    do {
      let req = ExpenseRequest(
        title: prepared.title,
        amount: max(prepared.draft.amount, 0),
        pillar: prepared.draft.pillar,
        occurredOn: self.dayString(from: prepared.draft.occurredOn),
        linkedPlanItemId: prepared.draft.linkedPlanItemID?.uuidString,
        categoryId: prepared.draft.categoryId,
        splitMode: prepared.draft.splitMode,
        userSharePercent: prepared.draft.userSharePercent,
        foreignAmount: prepared.draft.foreignAmount,
        foreignCurrency: prepared.draft.foreignCurrency,
        exchangeRate: prepared.draft.exchangeRate
      )
      let updated = try await expensesService.updateExpense(expenseId: expenseID.uuidString, payload: req)
      if let mapped = mapExpenseResponse(updated) {
        activities.removeAll { $0.id == mapped.id }
        activities.insert(mapped, at: 0)
        activities.sort { $0.occurredOn > $1.occurredOn }
      }
      refreshDerivedSummariesFromLocal()
      notifyDataDidChange()
      return true
    } catch {
      let message = "Could not update expense: \(error.localizedDescription)"
      self.errorMessage = message
      return false
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

  private func ensureSnapshotExistsForSelectedMonth() async throws -> MonthlyBudgetSnapshot {
    if let existing = snapshot(for: selectedMonthStart) {
      return existing
    }

    let monthStart = calendar.startOfMonth(for: selectedMonthStart)
    let template = monthlySnapshots.last ?? MonthlyBudgetSnapshot(
      monthStart: monthStart,
      netSalary: 0,
      targetShares: BudgetPillar.defaultShares,
      items: []
    )

    var targetSharesRequest: [String: Double] = [:]
    for (key, value) in template.targetShares {
      targetSharesRequest[key.rawValue] = value
    }

    logger.debug("Creating missing snapshot for month=\(self.dayString(from: monthStart), privacy: .public)")
    let created = try await expensesService.createBudgetSnapshot(
      request: BudgetSnapshotRequest(
        monthStart: self.dayString(from: monthStart),
        netSalary: template.netSalary,
        targetShares: targetSharesRequest
      )
    )

    guard let id = UUID(uuidString: created.id),
          let createdMonthStart = self.parseDayString(created.monthStart) else {
      throw NSError(
        domain: "BudgetPlannerViewModel",
        code: 1001,
        userInfo: [NSLocalizedDescriptionKey: "Server returned an invalid snapshot identifier."]
      )
    }

    let newSnapshot = MonthlyBudgetSnapshot(
      id: id,
      monthStart: createdMonthStart,
      netSalary: created.netSalary,
      targetShares: mapTargetShares(created.targetShares),
      items: []
    )
    monthlySnapshots.append(newSnapshot)
    monthlySnapshots.sort { $0.monthStart < $1.monthStart }
    selectedMonthStart = createdMonthStart
    return newSnapshot
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

  private var selectedMonthSnapshotIndex: Int? {
    monthlySnapshots.firstIndex(where: {
      calendar.isDate($0.monthStart, equalTo: selectedMonthStart, toGranularity: .month)
    })
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

  private static func makeAvailableMonths(
    snapshots: [MonthlyBudgetSnapshot],
    activities: [BudgetActivity],
    calendar: Calendar
  ) -> [Date] {
    var months: [Date] = snapshots.map { calendar.startOfMonth(for: $0.monthStart) }
    months.append(contentsOf: activities.map { calendar.startOfMonth(for: $0.occurredOn) })

    let deduped = Set(months)
    return deduped.sorted(by: >)
  }

  private func normalizeShares(_ shares: [BudgetPillar: Double]) -> [BudgetPillar: Double] {
    var sanitized = shares.reduce(into: [BudgetPillar: Double]()) { result, entry in
      result[entry.key] = max(entry.value, 0)
    }
    for pillar in BudgetPillar.standardPillars where sanitized[pillar] == nil {
      sanitized[pillar] = pillar.defaultTargetShare
    }
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

  private func mapMonthSummary(_ report: BudgetMonthSummaryResponse) -> BudgetMonthSummary? {
    guard let monthStart = self.parseDayString(report.monthStart) else { return nil }

    return BudgetMonthSummary(
      monthStart: monthStart,
      planned: report.planned,
      actual: report.actual,
      salary: report.salary,
      myPlanned: report.myPlanned,
      partnerPlanned: report.partnerPlanned,
      myActual: report.myActual,
      partnerActual: report.partnerActual,
      pillarActuals: mapPillarValues(report.pillarActuals),
      pillarPlans: mapPillarValues(report.pillarPlans),
      myPillarActuals: mapPillarValues(report.myPillarActuals),
      partnerPillarActuals: mapPillarValues(report.partnerPillarActuals),
      myPillarPlans: mapPillarValues(report.myPillarPlans),
      partnerPillarPlans: mapPillarValues(report.partnerPillarPlans)
    )
  }

  private func mapPillarValues(_ values: [String: Double]) -> [BudgetPillar: Double] {
    var mapped: [BudgetPillar: Double] = [:]
    for (key, value) in values {
      if let pillar = BudgetPillar(rawValue: key) {
        mapped[pillar] = value
      }
    }
    return mapped
  }

  private func mapTargetShares(_ values: [String: Double]) -> [BudgetPillar: Double] {
    var mapped = BudgetPillar.defaultShares
    for (key, value) in values {
      if let pillar = BudgetPillar(rawValue: key) {
        mapped[pillar] = value
      }
    }
    return mapped
  }

  private func mapSnapshotResponse(
    _ snapshot: BudgetSnapshotResponse,
    existingItems: [BudgetPlanItem]
  ) -> MonthlyBudgetSnapshot {
    MonthlyBudgetSnapshot(
      id: UUID(uuidString: snapshot.id) ?? UUID(),
      monthStart: parseDayString(snapshot.monthStart) ?? selectedMonthStart,
      netSalary: snapshot.netSalary,
      targetShares: mapTargetShares(snapshot.targetShares),
      items: existingItems
    )
  }

  private func mapPlanItemResponse(_ item: BudgetPlanItemResponse) -> BudgetPlanItem? {
    guard let itemID = UUID(uuidString: item.id) else { return nil }
    let catName = item.categoryId.flatMap { catId in
      categories.first(where: { $0.id == catId })?.name
    }
    return BudgetPlanItem(
      id: itemID,
      title: item.title,
      plannedAmount: item.plannedAmount,
      pillar: item.pillar,
      categoryId: item.categoryId,
      categoryName: catName,
      splitMode: item.splitMode,
      userSharePercent: item.userSharePercent
    )
  }

  private func mapExpenseResponse(_ expense: ExpenseResponse) -> BudgetActivity? {
    guard let expenseID = UUID(uuidString: expense.id),
          let occurredOn = parseDayString(expense.occurredOn) else {
      return nil
    }

    return BudgetActivity(
      id: expenseID,
      title: expense.title,
      amount: expense.amount,
      pillar: expense.pillar,
      occurredOn: occurredOn,
      linkedPlanItemID: expense.linkedPlanItemId.flatMap(UUID.init(uuidString:)),
      splitMode: expense.splitMode,
      userSharePercent: expense.userSharePercent,
      foreignAmount: expense.foreignAmount,
      foreignCurrency: expense.foreignCurrency,
      exchangeRate: expense.exchangeRate
    )
  }

  private func upsertSnapshot(_ snapshot: MonthlyBudgetSnapshot) {
    if let existingIndex = monthlySnapshots.firstIndex(where: { $0.id == snapshot.id }) {
      monthlySnapshots[existingIndex] = snapshot
    } else if let existingMonthIndex = monthlySnapshots.firstIndex(where: {
      calendar.isDate($0.monthStart, equalTo: snapshot.monthStart, toGranularity: .month)
    }) {
      monthlySnapshots[existingMonthIndex] = snapshot
    } else {
      monthlySnapshots.append(snapshot)
    }
    monthlySnapshots.sort { $0.monthStart < $1.monthStart }
  }

  private func refreshDerivedSummariesFromLocal() {
    let localMonthlySummaries = Self.makeLocalMonthlySummaries(
      snapshots: monthlySnapshots,
      activities: activities,
      calendar: calendar
    )
    monthlySummaries = localMonthlySummaries
    yearlySummaries = Self.makeLocalYearlySummaries(from: localMonthlySummaries, calendar: calendar)

    let months = Self.makeAvailableMonths(
      snapshots: monthlySnapshots,
      activities: activities,
      calendar: calendar
    )

    if let latestMonth = months.first,
       !months.contains(where: {
         calendar.isDate($0, equalTo: selectedMonthStart, toGranularity: .month)
       }) {
      selectedMonthStart = latestMonth
    }
  }

  private func notifyDataDidChange() {
    NotificationCenter.default.post(name: .budgetPlannerDataDidChange, object: nil)
  }

  private func parseDayString(_ value: String) -> Date? {
    let segments = value.split(separator: "-")
    guard segments.count == 3,
          let year = Int(segments[0]),
          let month = Int(segments[1]),
          let day = Int(segments[2]) else {
      return nil
    }
    return calendar.date(from: DateComponents(year: year, month: month, day: day))
  }

  private func dayString(from date: Date) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    guard let year = components.year,
          let month = components.month,
          let day = components.day else {
      return dateFormatter.string(from: date)
    }
    guard let normalizedDate = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
      return dateFormatter.string(from: date)
    }
    return dateFormatter.string(from: normalizedDate)
  }

  private func myPortion(of amount: Double, splitMode: ExpenseSplitMode, userSharePercent: Double) -> Double {
    switch splitMode {
    case .personal:
      return amount
    case .shared:
      return amount * (userSharePercent / 100)
    }
  }

  private func partnerPortion(of amount: Double, splitMode: ExpenseSplitMode, userSharePercent: Double) -> Double {
    amount - myPortion(of: amount, splitMode: splitMode, userSharePercent: userSharePercent)
  }

  private static func myPortion(of amount: Double, splitMode: ExpenseSplitMode, userSharePercent: Double) -> Double {
    switch splitMode {
    case .personal:
      return amount
    case .shared:
      return amount * (userSharePercent / 100)
    }
  }

  private static func partnerPortion(of amount: Double, splitMode: ExpenseSplitMode, userSharePercent: Double) -> Double {
    amount - myPortion(of: amount, splitMode: splitMode, userSharePercent: userSharePercent)
  }

  private static func makeLocalMonthlySummaries(
    snapshots: [MonthlyBudgetSnapshot],
    activities: [BudgetActivity],
    calendar: Calendar
  ) -> [BudgetMonthSummary] {
    snapshots.sorted { $0.monthStart < $1.monthStart }.map { snapshot in
      let monthActivities = activities.filter {
        calendar.isDate($0.occurredOn, equalTo: snapshot.monthStart, toGranularity: .month)
      }

      let planned = snapshot.items.reduce(0) { $0 + $1.plannedAmount }
      let actual = monthActivities.reduce(0) { $0 + $1.amount }
      let myPlanned = snapshot.items.reduce(0) {
        $0 + myPortion(of: $1.plannedAmount, splitMode: $1.splitMode, userSharePercent: $1.userSharePercent)
      }
      let partnerPlanned = planned - myPlanned
      let myActual = monthActivities.reduce(0) {
        $0 + myPortion(of: $1.amount, splitMode: $1.splitMode, userSharePercent: $1.userSharePercent)
      }
      let partnerActual = actual - myActual

      let monthPillars = resolvedPillars(snapshot: snapshot, activities: monthActivities)

      var pillarPlans: [BudgetPillar: Double] = [:]
      var myPillarPlans: [BudgetPillar: Double] = [:]
      var partnerPillarPlans: [BudgetPillar: Double] = [:]
      for pillar in monthPillars {
        let pillarItems = snapshot.items.filter { $0.pillar == pillar }
        let pillarPlanned = pillarItems.reduce(0) { $0 + $1.plannedAmount }
        let myPillarPlanned = pillarItems.reduce(0) {
          $0 + myPortion(of: $1.plannedAmount, splitMode: $1.splitMode, userSharePercent: $1.userSharePercent)
        }
        pillarPlans[pillar] = pillarPlanned
        myPillarPlans[pillar] = myPillarPlanned
        partnerPillarPlans[pillar] = pillarPlanned - myPillarPlanned
      }

      var pillarActuals: [BudgetPillar: Double] = [:]
      var myPillarActuals: [BudgetPillar: Double] = [:]
      var partnerPillarActuals: [BudgetPillar: Double] = [:]
      for pillar in monthPillars {
        let pillarActivities = monthActivities.filter { $0.pillar == pillar }
        let pillarActual = pillarActivities.reduce(0) { $0 + $1.amount }
        let myPillarActual = pillarActivities.reduce(0) {
          $0 + myPortion(of: $1.amount, splitMode: $1.splitMode, userSharePercent: $1.userSharePercent)
        }
        pillarActuals[pillar] = pillarActual
        myPillarActuals[pillar] = myPillarActual
        partnerPillarActuals[pillar] = pillarActual - myPillarActual
      }

      return BudgetMonthSummary(
        monthStart: snapshot.monthStart,
        planned: planned,
        actual: actual,
        salary: snapshot.netSalary,
        myPlanned: myPlanned,
        partnerPlanned: partnerPlanned,
        myActual: myActual,
        partnerActual: partnerActual,
        pillarActuals: pillarActuals,
        pillarPlans: pillarPlans,
        myPillarActuals: myPillarActuals,
        partnerPillarActuals: partnerPillarActuals,
        myPillarPlans: myPillarPlans,
        partnerPillarPlans: partnerPillarPlans
      )
    }
  }

  private static func resolvedPillars(
    snapshot: MonthlyBudgetSnapshot,
    activities: [BudgetActivity]
  ) -> [BudgetPillar] {
    var pillars = Set(BudgetPillar.standardPillars)
    pillars.formUnion(snapshot.targetShares.keys)
    pillars.formUnion(snapshot.items.map(\.pillar))
    pillars.formUnion(activities.map(\.pillar))
    return BudgetPillar.sortedForDisplay(pillars)
  }

  private static func makeLocalYearlySummaries(
    from monthlySummaries: [BudgetMonthSummary],
    calendar: Calendar
  ) -> [BudgetYearSummary] {
    let grouped = Dictionary(grouping: monthlySummaries) {
      calendar.component(.year, from: $0.monthStart)
    }

    return grouped
      .map { year, summaries in
        BudgetYearSummary(
          year: year,
          planned: summaries.reduce(0) { $0 + $1.planned },
          actual: summaries.reduce(0) { $0 + $1.actual },
          salary: summaries.reduce(0) { $0 + $1.salary },
          myPlanned: summaries.reduce(0) { $0 + $1.myPlanned },
          partnerPlanned: summaries.reduce(0) { $0 + $1.partnerPlanned },
          myActual: summaries.reduce(0) { $0 + $1.myActual },
          partnerActual: summaries.reduce(0) { $0 + $1.partnerActual }
        )
      }
      .sorted { $0.year > $1.year }
  }

  private static func mergeMonthlySummaries(
    preferred: [BudgetMonthSummary],
    fallback: [BudgetMonthSummary],
    calendar: Calendar
  ) -> [BudgetMonthSummary] {
    var mergedByMonth: [Date: BudgetMonthSummary] = [:]

    for summary in fallback {
      let monthKey = calendar.startOfMonth(for: summary.monthStart)
      mergedByMonth[monthKey] = summary
    }

    for summary in preferred {
      let monthKey = calendar.startOfMonth(for: summary.monthStart)
      mergedByMonth[monthKey] = summary
    }

    return mergedByMonth
      .values
      .sorted { $0.monthStart < $1.monthStart }
  }

  private static func mergeYearlySummaries(
    preferred: [BudgetYearSummary],
    fallback: [BudgetYearSummary]
  ) -> [BudgetYearSummary] {
    var mergedByYear: [Int: BudgetYearSummary] = [:]

    for summary in fallback {
      mergedByYear[summary.year] = summary
    }

    for summary in preferred {
      mergedByYear[summary.year] = summary
    }

    return mergedByYear
      .values
      .sorted { $0.year > $1.year }
  }
}

private extension Calendar {
  func startOfMonth(for date: Date) -> Date {
    self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
  }
}

private extension String {
  var normalizedBudgetKey: String {
    String(self).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
}

extension Notification.Name {
  static let budgetPlannerDataDidChange = Notification.Name("budgetPlannerDataDidChange")
}
