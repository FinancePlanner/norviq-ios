import SwiftUI
import StockPlanShared

extension BudgetPillar {
  public var title: String {
    if self == .fundamentals { return "Fundamentals" }
    if self == .futureYou { return "Future You" }
    if self == .fun { return "Fun" }

    let pattern = "([a-z0-9])([A-Z])"
    let spaced = rawValue.replacingOccurrences(
      of: pattern,
      with: "$1 $2",
      options: .regularExpression
    )
    let words = spaced
      .replacingOccurrences(of: "[^A-Za-z0-9]+", with: " ", options: .regularExpression)
      .split(separator: " ")
      .map(String.init)
      .map { $0.capitalized }
    return words.joined(separator: " ")
  }

  public var subtitle: String {
    if self == .fundamentals { return "Daily life and recurring essentials." }
    if self == .futureYou { return "Investments and long-term goals." }
    if self == .fun { return "Lifestyle, travel, and discretionary spending." }
    return "Custom spending category."
  }

  public var symbol: String {
    if self == .fundamentals { return "house" }
    if self == .futureYou { return "chart.line.uptrend.xyaxis" }
    if self == .fun { return "sparkles" }
    return "square.stack.3d.up"
  }

  public var defaultTargetShare: Double {
    if self == .fundamentals { return 0.50 }
    if self == .futureYou { return 0.20 }
    if self == .fun { return 0.30 }
    return 0
  }

  public func color(for scheme: ColorScheme) -> Color {
    if self == .fundamentals { return AppTheme.Colors.tint(for: scheme) }
    if self == .futureYou { return .indigo }
    if self == .fun { return AppTheme.Colors.secondaryTint(for: scheme) }

    let palette: [Color] = [.teal, .cyan, .mint, .orange, .pink, .brown, .blue]
    let hash = rawValue.unicodeScalars.reduce(0) { partial, scalar in
      partial &+ Int(scalar.value)
    }
    return palette[hash % palette.count]
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
  var categoryId: String?
  var categoryName: String?
  var splitMode: ExpenseSplitMode
  var userSharePercent: Double

  init(
    id: UUID = UUID(),
    title: String,
    plannedAmount: Double,
    pillar: BudgetPillar,
    categoryId: String? = nil,
    categoryName: String? = nil,
    splitMode: ExpenseSplitMode = .personal,
    userSharePercent: Double = 100
  ) {
    self.id = id
    self.title = title
    self.plannedAmount = plannedAmount
    self.pillar = pillar
    self.categoryId = categoryId
    self.categoryName = categoryName
    self.splitMode = splitMode
    self.userSharePercent = userSharePercent
  }

  var isSubscription: Bool {
    categoryName?.lowercased() == "subscriptions"
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
  var foreignAmount: Double?
  var foreignCurrency: String?
  var exchangeRate: Double?

  init(
    id: UUID = UUID(),
    title: String,
    amount: Double,
    pillar: BudgetPillar,
    occurredOn: Date,
    linkedPlanItemID: UUID? = nil,
    splitMode: ExpenseSplitMode = .personal,
    userSharePercent: Double = 100,
    foreignAmount: Double? = nil,
    foreignCurrency: String? = nil,
    exchangeRate: Double? = nil
  ) {
    self.id = id
    self.title = title
    self.amount = amount
    self.pillar = pillar
    self.occurredOn = occurredOn
    self.linkedPlanItemID = linkedPlanItemID
    self.splitMode = splitMode
    self.userSharePercent = userSharePercent
    self.foreignAmount = foreignAmount
    self.foreignCurrency = foreignCurrency
    self.exchangeRate = exchangeRate
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

struct BudgetPlanItemDraft: Identifiable, Sendable {
  let id = UUID()
  var itemID: UUID?
  var placeholderItemID: UUID?
  var title: String
  var plannedAmount: Double
  var pillar: BudgetPillar
  var categoryId: String?
  var splitMode: ExpenseSplitMode
  var userSharePercent: Double

  init(
    itemID: UUID? = nil,
    placeholderItemID: UUID? = nil,
    title: String,
    plannedAmount: Double,
    pillar: BudgetPillar,
    categoryId: String? = nil,
    splitMode: ExpenseSplitMode = .personal,
    userSharePercent: Double = 100
  ) {
    self.itemID = itemID
    self.placeholderItemID = placeholderItemID
    self.title = title
    self.plannedAmount = plannedAmount
    self.pillar = pillar
    self.categoryId = categoryId
    self.splitMode = splitMode
    self.userSharePercent = userSharePercent
  }
}

struct BudgetActivityDraft: Sendable {
  var title: String
  var amount: Double
  var pillar: BudgetPillar
  var occurredOn: Date
  var linkedPlanItemID: UUID?
  var categoryId: String?
  var splitMode: ExpenseSplitMode
  var userSharePercent: Double
  var foreignAmount: Double?
  var foreignCurrency: String?
  var exchangeRate: Double?

  init(
    title: String,
    amount: Double,
    pillar: BudgetPillar,
    occurredOn: Date,
    linkedPlanItemID: UUID? = nil,
    categoryId: String? = nil,
    splitMode: ExpenseSplitMode = .personal,
    userSharePercent: Double = 100,
    foreignAmount: Double? = nil,
    foreignCurrency: String? = nil,
    exchangeRate: Double? = nil
  ) {
    self.title = title
    self.amount = amount
    self.pillar = pillar
    self.occurredOn = occurredOn
    self.linkedPlanItemID = linkedPlanItemID
    self.categoryId = categoryId
    self.splitMode = splitMode
    self.userSharePercent = userSharePercent
    self.foreignAmount = foreignAmount
    self.foreignCurrency = foreignCurrency
    self.exchangeRate = exchangeRate
  }
}

extension BudgetPillar {
  static var standardPillars: [BudgetPillar] {
    BudgetPillar.allCases
  }

  static func sortedForDisplay<S: Sequence>(_ pillars: S) -> [BudgetPillar] where S.Element == BudgetPillar {
    Array(Set(pillars)).sorted { lhs, rhs in
      let lhsRank = sortRank(lhs)
      let rhsRank = sortRank(rhs)
      if lhsRank == rhsRank {
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
      }
      return lhsRank < rhsRank
    }
  }

  private static func sortRank(_ pillar: BudgetPillar) -> Int {
    if pillar == .fundamentals { return 0 }
    if pillar == .futureYou { return 1 }
    if pillar == .fun { return 2 }
    return 3
  }

  static var defaultShares: [BudgetPillar: Double] {
    Dictionary(uniqueKeysWithValues: BudgetPillar.standardPillars.map { ($0, $0.defaultTargetShare) })
  }
}
