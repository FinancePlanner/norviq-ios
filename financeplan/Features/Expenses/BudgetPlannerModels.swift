import SwiftUI

enum BudgetPillar: String, CaseIterable, Identifiable, Hashable {
  case fundamentals
  case futureYou
  case fun

  var id: String { rawValue }

  var title: String {
    switch self {
    case .fundamentals:
      "Fundamentals"
    case .futureYou:
      "Future You"
    case .fun:
      "Fun"
    }
  }

  var subtitle: String {
    switch self {
    case .fundamentals:
      "Daily life and recurring essentials."
    case .futureYou:
      "Investments and long-term goals."
    case .fun:
      "Lifestyle, travel, and discretionary spending."
    }
  }

  var symbol: String {
    switch self {
    case .fundamentals:
      "house"
    case .futureYou:
      "chart.line.uptrend.xyaxis"
    case .fun:
      "sparkles"
    }
  }

  var defaultTargetShare: Double {
    switch self {
    case .fundamentals:
      0.50
    case .futureYou:
      0.20
    case .fun:
      0.30
    }
  }

  func color(for scheme: ColorScheme) -> Color {
    switch self {
    case .fundamentals:
      AppTheme.Colors.tint(for: scheme)
    case .futureYou:
      .indigo
    case .fun:
      AppTheme.Colors.secondaryTint(for: scheme)
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

  init(id: UUID = UUID(), title: String, plannedAmount: Double, pillar: BudgetPillar) {
    self.id = id
    self.title = title
    self.plannedAmount = plannedAmount
    self.pillar = pillar
  }
}

struct BudgetActivity: Identifiable, Equatable {
  let id: UUID
  var title: String
  var amount: Double
  var pillar: BudgetPillar
  var occurredOn: Date
  var linkedPlanItemID: UUID?

  init(
    id: UUID = UUID(),
    title: String,
    amount: Double,
    pillar: BudgetPillar,
    occurredOn: Date,
    linkedPlanItemID: UUID? = nil
  ) {
    self.id = id
    self.title = title
    self.amount = amount
    self.pillar = pillar
    self.occurredOn = occurredOn
    self.linkedPlanItemID = linkedPlanItemID
  }
}

struct BudgetMonthSummary: Identifiable {
  var id: Date { monthStart }
  let monthStart: Date
  let planned: Double
  let actual: Double
  let salary: Double
  let pillarActuals: [BudgetPillar: Double]
  let pillarPlans: [BudgetPillar: Double]

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
}

struct BudgetYearSummary: Identifiable {
  let year: Int
  let planned: Double
  let actual: Double
  let salary: Double

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
  var title: String
  var plannedAmount: Double
  var pillar: BudgetPillar
}

struct BudgetActivityDraft {
  var title: String
  var amount: Double
  var pillar: BudgetPillar
  var occurredOn: Date
  var linkedPlanItemID: UUID?
}

extension BudgetPillar {
  static var defaultShares: [BudgetPillar: Double] {
    Dictionary(uniqueKeysWithValues: BudgetPillar.allCases.map { ($0, $0.defaultTargetShare) })
  }
}
