import Combine
import Foundation
import OSLog
import Factory
import StockPlanShared

@MainActor
final class BudgetPlannerViewModel: ObservableObject {
  @Published private(set) var monthlySnapshots: [MonthlyBudgetSnapshot] = []
  @Published private(set) var activities: [BudgetActivity] = []
  @Published private(set) var monthlySummaries: [BudgetMonthSummary] = []
  @Published private(set) var yearlySummaries: [BudgetYearSummary] = []
  @Published private(set) var reportSuggestions: [ReportSuggestionResponse] = []
  @Published private(set) var isSuggestionsLoading = false
  @Published private(set) var suggestionsUnavailable = false
  @Published private(set) var partnerDisplayName: String = "Partner"
  @Published var selectedMonthStart: Date = .now
  @Published var isLoading = false
  @Published var errorMessage: String? = nil

  private let calendar: Calendar
  private let expensesService: any ExpensesServicing
  private var hasLoadedOnce = false
  private var pendingForceReload = false
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
    category: "BudgetPlannerViewModel"
  )

  private let dateFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd"
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
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
          async let fetchPartner = expensesService.getHouseholdPartner()
          async let fetchSnapshots = expensesService.getSnapshots(year: nil, month: nil)
          async let fetchItems = expensesService.getAllPlanItems()
          async let fetchExpenses = expensesService.getExpenses(from: nil, to: nil)
          async let fetchMonthlyReports = expensesService.getMonthlyExpenseReports(from: nil, to: nil)
          async let fetchYearlyReports = expensesService.getYearlyExpenseReports(from: nil, to: nil)

          let (partner, fetchedSnapshots, fetchedItems, fetchedExpenses, fetchedMonthlyReports, fetchedYearlyReports) = try await (
            fetchPartner,
            fetchSnapshots,
            fetchItems,
            fetchExpenses,
            fetchMonthlyReports,
            fetchYearlyReports
          )
          self.partnerDisplayName = partner.displayName ?? "Partner"

          let itemsBySnapshotId = Dictionary(grouping: fetchedItems, by: \.snapshotId)

          var newSnapshots = fetchedSnapshots.compactMap { snap -> MonthlyBudgetSnapshot? in
              guard let id = UUID(uuidString: snap.id),
                    let monthStart = self.dateFormatter.date(from: snap.monthStart) else { return nil }

              var targetShares = BudgetPillar.defaultShares
              for (key, val) in snap.targetShares {
                  if let pillar = BudgetPillar(rawValue: key) {
                      targetShares[pillar] = val
                  }
              }

              let mappedItems = (itemsBySnapshotId[snap.id] ?? []).compactMap { item -> BudgetPlanItem? in
                  guard let itemId = UUID(uuidString: item.id) else { return nil }
                  return BudgetPlanItem(
                    id: itemId,
                    title: item.title,
                    plannedAmount: item.plannedAmount,
                    pillar: item.pillar,
                    splitMode: item.splitMode,
                    userSharePercent: item.userSharePercent
                  )
              }

              return MonthlyBudgetSnapshot(
                  id: id,
                  monthStart: monthStart,
                  netSalary: snap.netSalary,
                  targetShares: targetShares,
                  items: mappedItems
              )
          }

          if newSnapshots.isEmpty {
              let start = calendar.startOfMonth(for: .now)
              let req = BudgetSnapshotRequest(monthStart: self.dateFormatter.string(from: start), netSalary: 2700, targetShares: [:])
              let created = try await expensesService.createBudgetSnapshot(request: req)
              if let id = UUID(uuidString: created.id) {
                  newSnapshots.append(
                    MonthlyBudgetSnapshot(
                      id: id,
                      monthStart: start,
                      netSalary: created.netSalary,
                      targetShares: mapTargetShares(created.targetShares),
                      items: []
                    )
                  )
              }
          }

          let newActivities = fetchedExpenses.compactMap { exp -> BudgetActivity? in
              guard let id = UUID(uuidString: exp.id),
                    let date = self.dateFormatter.date(from: exp.occurredOn) else { return nil }
              let linkedId = exp.linkedPlanItemId.flatMap { UUID(uuidString: $0) }
              return BudgetActivity(
                id: id,
                title: exp.title,
                amount: exp.amount,
                pillar: exp.pillar,
                occurredOn: date,
                linkedPlanItemID: linkedId,
                splitMode: exp.splitMode,
                userSharePercent: exp.userSharePercent
              )
          }

          newSnapshots.sort { $0.monthStart < $1.monthStart }
          self.monthlySnapshots = newSnapshots
          self.activities = newActivities.sorted { $0.occurredOn > $1.occurredOn }

          let fetchedMonthlySummaries = fetchedMonthlyReports.compactMap(mapMonthSummary)
          let localMonthlySummaries = Self.makeLocalMonthlySummaries(
            snapshots: newSnapshots,
            activities: self.activities,
            calendar: self.calendar
          )
          self.monthlySummaries = Self.mergeMonthlySummaries(
            preferred: fetchedMonthlySummaries,
            fallback: localMonthlySummaries,
            calendar: self.calendar
          )

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
            preferred: fetchedYearlySummaries,
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
          self.errorMessage = "Could not refresh planner data: \(error.localizedDescription)"
      }

      isLoading = false
      isSuggestionsLoading = false

      if pendingForceReload {
          pendingForceReload = false
          await load(force: true)
      }
  }

  var topReportSuggestion: ReportSuggestionResponse? {
    reportSuggestions.first
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
      netSalary: 2700,
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
            for (k,v) in template.targetShares { stringShares[k.rawValue] = v }
            
            let req = BudgetSnapshotRequest(monthStart: self.dateFormatter.string(from: nextMonthStart), netSalary: template.netSalary, targetShares: stringShares)
            let createdSnap = try await expensesService.createBudgetSnapshot(request: req)
            
            for item in template.items {
                let itemReq = BudgetPlanItemRequest(
                  snapshotId: createdSnap.id,
                  title: item.title,
                  plannedAmount: item.plannedAmount,
                  pillar: item.pillar,
                  splitMode: item.splitMode,
                  userSharePercent: item.userSharePercent
                )
                _ = try await expensesService.createPlanItem(payload: itemReq)
            }
            await load(force: true)
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
          selectedMonthStart = monthlySnapshots.last!.monthStart
      }
      
      Task {
          do {
              try await expensesService.deleteSnapshot(snapshotId: snapshotId.uuidString)
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
            let snapshot = try await ensureSnapshotExistsForSelectedMonth()
            guard let selectedMonthSnapshotIndex else {
              throw NSError(
                domain: "BudgetPlannerViewModel",
                code: 1004,
                userInfo: [NSLocalizedDescriptionKey: "Could not resolve selected month snapshot."]
              )
            }
            monthlySnapshots[selectedMonthSnapshotIndex].netSalary = newAmount
            var stringShares: [String: Double] = [:]
            for (k,v) in snapshot.targetShares { stringShares[k.rawValue] = v }
            let req = BudgetSnapshotRequest(monthStart: self.dateFormatter.string(from: snapshot.monthStart), netSalary: newAmount, targetShares: stringShares)
            _ = try await expensesService.updateSnapshot(snapshotId: snapshot.id.uuidString, payload: req)
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
            let snapshot = try await ensureSnapshotExistsForSelectedMonth()
            guard let selectedMonthSnapshotIndex else {
              throw NSError(
                domain: "BudgetPlannerViewModel",
                code: 1005,
                userInfo: [NSLocalizedDescriptionKey: "Could not resolve selected month snapshot."]
              )
            }
            monthlySnapshots[selectedMonthSnapshotIndex].targetShares = normalized
            var stringShares: [String: Double] = [:]
            for (k,v) in normalized { stringShares[k.rawValue] = v }
            let req = BudgetSnapshotRequest(monthStart: self.dateFormatter.string(from: snapshot.monthStart), netSalary: snapshot.netSalary, targetShares: stringShares)
            _ = try await expensesService.updateSnapshot(snapshotId: snapshot.id.uuidString, payload: req)
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
    let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else {
      errorMessage = "Planned item needs a name."
      return
    }

    let plannedAmount = max(draft.plannedAmount, 0)
    Task {
      do {
        let snapshot = try await ensureSnapshotExistsForSelectedMonth()
        guard let selectedMonthSnapshotIndex else {
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

        if let itemID = draft.itemID,
          let existingIndex = monthlySnapshots[selectedMonthSnapshotIndex].items.firstIndex(where: { $0.id == itemID })
        {
          monthlySnapshots[selectedMonthSnapshotIndex].items[existingIndex].title = title
          monthlySnapshots[selectedMonthSnapshotIndex].items[existingIndex].plannedAmount = plannedAmount
          monthlySnapshots[selectedMonthSnapshotIndex].items[existingIndex].pillar = draft.pillar
          monthlySnapshots[selectedMonthSnapshotIndex].items[existingIndex].splitMode = draft.splitMode
          monthlySnapshots[selectedMonthSnapshotIndex].items[existingIndex].userSharePercent = draft.userSharePercent

          logger.debug("Attempting plan item update id=\(itemID.uuidString, privacy: .public) title=\(title, privacy: .public)")
          let req = BudgetPlanItemRequest(
            snapshotId: snapshotId.uuidString,
            title: title,
            plannedAmount: plannedAmount,
            pillar: draft.pillar,
            splitMode: draft.splitMode,
            userSharePercent: draft.userSharePercent
          )
          _ = try await expensesService.updatePlanItem(itemId: itemID.uuidString, payload: req)
          logger.debug("Plan item update succeeded id=\(itemID.uuidString, privacy: .public)")
        } else {
          let tempId = UUID()
          monthlySnapshots[selectedMonthSnapshotIndex].items.append(
            BudgetPlanItem(
              id: tempId,
              title: title,
              plannedAmount: plannedAmount,
              pillar: draft.pillar,
              splitMode: draft.splitMode,
              userSharePercent: draft.userSharePercent
            )
          )

          logger.debug("Attempting plan item create title=\(title, privacy: .public)")
          let req = BudgetPlanItemRequest(
            snapshotId: snapshotId.uuidString,
            title: title,
            plannedAmount: plannedAmount,
            pillar: draft.pillar,
            splitMode: draft.splitMode,
            userSharePercent: draft.userSharePercent
          )
          _ = try await expensesService.createPlanItem(payload: req)
          logger.debug("Plan item create succeeded title=\(title, privacy: .public)")
        }

        monthlySnapshots[selectedMonthSnapshotIndex].items.sort {
          if $0.pillar == $1.pillar {
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
          }
          return $0.pillar.rawValue < $1.pillar.rawValue
        }
        await load(force: true)
      } catch {
        self.errorMessage = "Could not save planned item: \(error.localizedDescription)"
        logger.error("Plan item save failed: \(error.localizedDescription, privacy: .public)")
        await load(force: true)
      }
    }
  }

  func removePlanItem(_ itemID: UUID) {
    guard let selectedMonthSnapshotIndex else { return }
    monthlySnapshots[selectedMonthSnapshotIndex].items.removeAll { $0.id == itemID }
    Task {
        do {
            try await expensesService.deletePlanItem(itemId: itemID.uuidString)
        } catch {
            self.errorMessage = error.localizedDescription
            await load(force: true)
        }
    }
  }

  func recordExpense(_ draft: BudgetActivityDraft) {
    let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else {
      errorMessage = "Spend entry needs a title."
      return
    }

    let tempId = UUID()
    activities.insert(
      BudgetActivity(
        id: tempId,
        title: title,
        amount: max(draft.amount, 0),
        pillar: draft.pillar,
        occurredOn: draft.occurredOn,
        linkedPlanItemID: draft.linkedPlanItemID,
        splitMode: draft.splitMode,
        userSharePercent: draft.userSharePercent
      ),
      at: 0
    )

    let activityMonth = calendar.startOfMonth(for: draft.occurredOn)
    selectedMonthStart = activityMonth
    
    Task {
        do {
            logger.debug("Attempting expense create title=\(title, privacy: .public) amount=\(draft.amount, privacy: .public)")
            let req = ExpenseRequest(
                title: title,
                amount: max(draft.amount, 0),
                pillar: draft.pillar,
                occurredOn: self.dateFormatter.string(from: draft.occurredOn),
                linkedPlanItemId: draft.linkedPlanItemID?.uuidString,
                splitMode: draft.splitMode,
                userSharePercent: draft.userSharePercent
            )
            _ = try await expensesService.createExpense(request: req)
            logger.debug("Expense create succeeded title=\(title, privacy: .public)")
            await load(force: true)
        } catch {
            self.errorMessage = "Could not record spend: \(error.localizedDescription)"
            logger.error("Expense create failed: \(error.localizedDescription, privacy: .public)")
            await load(force: true)
        }
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
      netSalary: 2700,
      targetShares: BudgetPillar.defaultShares,
      items: []
    )

    var targetSharesRequest: [String: Double] = [:]
    for (key, value) in template.targetShares {
      targetSharesRequest[key.rawValue] = value
    }

    logger.debug("Creating missing snapshot for month=\(self.dateFormatter.string(from: monthStart), privacy: .public)")
    let created = try await expensesService.createBudgetSnapshot(
      request: BudgetSnapshotRequest(
        monthStart: self.dateFormatter.string(from: monthStart),
        netSalary: template.netSalary,
        targetShares: targetSharesRequest
      )
    )

    guard let id = UUID(uuidString: created.id),
          let createdMonthStart = self.dateFormatter.date(from: created.monthStart) else {
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

  private func mapMonthSummary(_ report: BudgetMonthSummaryResponse) -> BudgetMonthSummary? {
    guard let monthStart = self.dateFormatter.date(from: report.monthStart) else { return nil }

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

      var pillarPlans: [BudgetPillar: Double] = [:]
      var myPillarPlans: [BudgetPillar: Double] = [:]
      var partnerPillarPlans: [BudgetPillar: Double] = [:]
      for pillar in BudgetPillar.allCases {
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
      for pillar in BudgetPillar.allCases {
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
    trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
}
