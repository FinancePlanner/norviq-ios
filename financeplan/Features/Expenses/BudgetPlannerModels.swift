import SwiftUI
import StockPlanShared

extension BudgetPillar: Identifiable {
  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .fundamentals:
      return "Fundamentals"
    case .futureYou:
      return "Future You"
    case .fun:
      return "Fun"
    }
  }

  public var subtitle: String {
    switch self {
    case .fundamentals:
      return "Daily life and recurring essentials."
    case .futureYou:
      return "Investments and long-term goals."
    case .fun:
      return "Lifestyle, travel, and discretionary spending."
    }
  }

  public var symbol: String {
    switch self {
    case .fundamentals:
      return "house"
    case .futureYou:
      return "chart.line.uptrend.xyaxis"
    case .fun:
      return "sparkles"
    }
  }

  public var defaultTargetShare: Double {
    switch self {
    case .fundamentals:
      return 0.50
    case .futureYou:
      return 0.20
    case .fun:
      return 0.30
    }
  }

  public func color(for scheme: ColorScheme) -> Color {
    switch self {
    case .fundamentals:
      return AppTheme.Colors.tint(for: scheme)
    case .futureYou:
      return .indigo
    case .fun:
      return AppTheme.Colors.secondaryTint(for: scheme)
    }
  }
}

struct MonthlyBudgetSnapshot: Identifiable, Equatable {
  let id: UUID
  var monthStart: Date
  var netSalary: Double
  var targetShares: [BudgetPillar: Double]
  var items: [BudgetPlanItem]

  init(
    id: UUID = UUID(),
    monthStart: Date,
    netSalary: Double,
    targetShares: [BudgetPillar: Double] = BudgetPillar.defaultShares,
    items: [BudgetPlanItem]
  ) {
    self.id = id
    self.monthStart = monthStart
    self.netSalary = netSalary
    self.targetShares = targetShares
    self.items = items
  }
}

struct BudgetPlanItem: Identifiable, Equatable {
  let id: UUID
  var title: String
  var plannedAmount: Double
  var pillar: BudgetPillar
  var splitMode: ExpenseSplitMode
  var userSharePercent: Double

  init(
    id: UUID = UUID(),
    title: String,
    plannedAmount: Double,
    pillar: BudgetPillar,
    splitMode: ExpenseSplitMode = .personal,
    userSharePercent: Double = 100
  ) {
    self.id = id
    self.title = title
    self.plannedAmount = plannedAmount
    self.pillar = pillar
    self.splitMode = splitMode
    self.userSharePercent = userSharePercent
  }
}

struct BudgetActivity: Identifiable, Equatable {
  let id: UUID
  var title: String
  var amount: Double
  var pillar: BudgetPillar
  var occurredOn: Date
  var linkedPlanItemID: UUID?
  var splitMode: ExpenseSplitMode
  var userSharePercent: Double

  init(
    id: UUID = UUID(),
    title: String,
    amount: Double,
    pillar: BudgetPillar,
    occurredOn: Date,
    linkedPlanItemID: UUID? = nil,
    splitMode: ExpenseSplitMode = .personal,
    userSharePercent: Double = 100
  ) {
    self.id = id
    self.title = title
    self.amount = amount
    self.pillar = pillar
    self.occurredOn = occurredOn
    self.linkedPlanItemID = linkedPlanItemID
    self.splitMode = splitMode
    self.userSharePercent = userSharePercent
  }
}

struct BudgetMonthSummary: Identifiable {
  var id: Date { monthStart }
  let monthStart: Date
  let planned: Double
  let actual: Double
  let salary: Double
  let myPlanned: Double
  let partnerPlanned: Double
  let myActual: Double
  let partnerActual: Double
  let pillarActuals: [BudgetPillar: Double]
  let pillarPlans: [BudgetPillar: Double]
  let myPillarActuals: [BudgetPillar: Double]
  let partnerPillarActuals: [BudgetPillar: Double]
  let myPillarPlans: [BudgetPillar: Double]
  let partnerPillarPlans: [BudgetPillar: Double]

  init(
    monthStart: Date,
    planned: Double,
    actual: Double,
    salary: Double,
    myPlanned: Double = 0,
    partnerPlanned: Double = 0,
    myActual: Double = 0,
    partnerActual: Double = 0,
    pillarActuals: [BudgetPillar: Double],
    pillarPlans: [BudgetPillar: Double],
    myPillarActuals: [BudgetPillar: Double] = [:],
    partnerPillarActuals: [BudgetPillar: Double] = [:],
    myPillarPlans: [BudgetPillar: Double] = [:],
    partnerPillarPlans: [BudgetPillar: Double] = [:]
  ) {
    self.monthStart = monthStart
    self.planned = planned
    self.actual = actual
    self.salary = salary
    self.myPlanned = myPlanned
    self.partnerPlanned = partnerPlanned
    self.myActual = myActual
    self.partnerActual = partnerActual
    self.pillarActuals = pillarActuals
    self.pillarPlans = pillarPlans
    self.myPillarActuals = myPillarActuals
    self.partnerPillarActuals = partnerPillarActuals
    self.myPillarPlans = myPillarPlans
    self.partnerPillarPlans = partnerPillarPlans
  }

  var shortLabel: String {
    monthStart.formatted(.dateTime.month(.abbreviated))
  }

  var longLabel: String {
    monthStart.formatted(.dateTime.month(.wide).year())
  }

  var remainingAfterPlanning: Double {
    salary - planned
  }

  var remainingAfterSpending: Double {
    salary - actual
  }

  var partnerRemainingAfterSpending: Double {
    partnerPlanned - partnerActual
  }
}

struct BudgetMonthChartPoint: Identifiable {
  let monthStart: Date
  let label: String
  let actual: Double

  var id: Date { monthStart }
}

struct BudgetYearSummary: Identifiable {
  let year: Int
  let planned: Double
  let actual: Double
  let salary: Double
  let myPlanned: Double
  let partnerPlanned: Double
  let myActual: Double
  let partnerActual: Double

  init(
    year: Int,
    planned: Double,
    actual: Double,
    salary: Double,
    myPlanned: Double = 0,
    partnerPlanned: Double = 0,
    myActual: Double = 0,
    partnerActual: Double = 0
  ) {
    self.year = year
    self.planned = planned
    self.actual = actual
    self.salary = salary
    self.myPlanned = myPlanned
    self.partnerPlanned = partnerPlanned
    self.myActual = myActual
    self.partnerActual = partnerActual
  }

  var id: Int { year }

  var remainingAfterSpending: Double {
    salary - actual
  }
}

struct PillarPlanningSummary: Identifiable {
  let pillar: BudgetPillar
  let targetAmount: Double
  let plannedAmount: Double
  let actualAmount: Double
  let unplannedActualAmount: Double

  var id: BudgetPillar { pillar }

  var availableToPlan: Double {
    targetAmount - plannedAmount
  }

  var varianceToTarget: Double {
    targetAmount - actualAmount
  }
}

struct BudgetPlanItemDraft: Identifiable {
  let id = UUID()
  var itemID: UUID?
  var placeholderItemID: UUID?
  var title: String
  var plannedAmount: Double
  var pillar: BudgetPillar
  var splitMode: ExpenseSplitMode
  var userSharePercent: Double

  init(
    itemID: UUID? = nil,
    placeholderItemID: UUID? = nil,
    title: String,
    plannedAmount: Double,
    pillar: BudgetPillar,
    splitMode: ExpenseSplitMode = .personal,
    userSharePercent: Double = 100
  ) {
    self.itemID = itemID
    self.placeholderItemID = placeholderItemID
    self.title = title
    self.plannedAmount = plannedAmount
    self.pillar = pillar
    self.splitMode = splitMode
    self.userSharePercent = userSharePercent
  }
}

struct BudgetActivityDraft {
  var title: String
  var amount: Double
  var pillar: BudgetPillar
  var occurredOn: Date
  var linkedPlanItemID: UUID?
  var splitMode: ExpenseSplitMode
  var userSharePercent: Double

  init(
    title: String,
    amount: Double,
    pillar: BudgetPillar,
    occurredOn: Date,
    linkedPlanItemID: UUID? = nil,
    splitMode: ExpenseSplitMode = .personal,
    userSharePercent: Double = 100
  ) {
    self.title = title
    self.amount = amount
    self.pillar = pillar
    self.occurredOn = occurredOn
    self.linkedPlanItemID = linkedPlanItemID
    self.splitMode = splitMode
    self.userSharePercent = userSharePercent
  }
}

extension BudgetPillar {
  static var defaultShares: [BudgetPillar: Double] {
    Dictionary(uniqueKeysWithValues: BudgetPillar.allCases.map { ($0, $0.defaultTargetShare) })
  }
}
