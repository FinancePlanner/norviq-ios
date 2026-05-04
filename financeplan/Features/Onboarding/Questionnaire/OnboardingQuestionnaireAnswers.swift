import Foundation

// MARK: - Goal (Screen 2, single-select)

enum OnboardingGoal: String, CaseIterable, Identifiable, Codable {
  case trackEverything
  case seeWhereMoneyGoes
  case planLongTerm
  case saveSpendSmarter
  case getSeriousAboutPortfolio
  case justLooking

  var id: String { rawValue }

  var emoji: String {
    switch self {
    case .trackEverything: "🧮"
    case .seeWhereMoneyGoes: "💸"
    case .planLongTerm: "📈"
    case .saveSpendSmarter: "🪙"
    case .getSeriousAboutPortfolio: "📊"
    case .justLooking: "🤔"
    }
  }

  var title: String {
    switch self {
    case .trackEverything: "Track everything in one place"
    case .seeWhereMoneyGoes: "See where my money actually goes"
    case .planLongTerm: "Plan for a long-term goal (retirement, house, FIRE)"
    case .saveSpendSmarter: "Save more, spend smarter"
    case .getSeriousAboutPortfolio: "Get serious about my portfolio"
    case .justLooking: "Honestly, just having a look"
    }
  }
}

// MARK: - Pain points (Screen 3, multi-select)

enum OnboardingPainPoint: String, CaseIterable, Identifiable, Codable {
  case scattered
  case mysterySpending
  case notOnTrack
  case spreadsheetChore
  case saveMoreVibe
  case overweight
  case forgetExpenses

  var id: String { rawValue }

  var emoji: String {
    switch self {
    case .scattered: "🧩"
    case .mysterySpending: "🕳️"
    case .notOnTrack: "📉"
    case .spreadsheetChore: "📓"
    case .saveMoreVibe: "🎯"
    case .overweight: "⚖️"
    case .forgetExpenses: "🔁"
    }
  }

  var title: String {
    switch self {
    case .scattered: "My investments are scattered across apps"
    case .mysterySpending: "I have no idea where my money goes"
    case .notOnTrack: "I can't tell if I'm actually on track"
    case .spreadsheetChore: "My spreadsheet is a chore"
    case .saveMoreVibe: "\"Save more\" is a vibe, not a plan"
    case .overweight: "I might be overweight in one stock — who knows"
    case .forgetExpenses: "I keep forgetting to log expenses"
    }
  }
}

// MARK: - Holding types (Screen 8a, multi-select)

enum OnboardingHoldingType: String, CaseIterable, Identifiable, Codable {
  case indexFunds
  case individualStocks
  case dividendPayers
  case international
  case bonds
  case justFiguringOut

  var id: String { rawValue }

  var emoji: String {
    switch self {
    case .indexFunds: "📊"
    case .individualStocks: "🏢"
    case .dividendPayers: "💎"
    case .international: "🌐"
    case .bonds: "🏛️"
    case .justFiguringOut: "🤔"
    }
  }

  var title: String {
    switch self {
    case .indexFunds: "Index funds & ETFs"
    case .individualStocks: "Individual stocks"
    case .dividendPayers: "Dividend payers"
    case .international: "International equities"
    case .bonds: "Bonds & treasuries"
    case .justFiguringOut: "Just figuring it out"
    }
  }
}

// MARK: - Spending leak categories (Screen 8b, multi-select)

enum OnboardingSpendingLeak: String, CaseIterable, Identifiable, Codable {
  case dining
  case subscriptions
  case shopping
  case travel
  case transport
  case smallDailySpends

  var id: String { rawValue }

  var emoji: String {
    switch self {
    case .dining: "🍔"
    case .subscriptions: "📺"
    case .shopping: "🛍️"
    case .travel: "✈️"
    case .transport: "🚗"
    case .smallDailySpends: "☕"
    }
  }

  var title: String {
    switch self {
    case .dining: "Dining & takeaway"
    case .subscriptions: "Subscriptions"
    case .shopping: "Shopping"
    case .travel: "Travel"
    case .transport: "Transport"
    case .smallDailySpends: "Small daily spends"
    }
  }

  /// Plain-text noun for inline mention in dynamic copy (e.g. Screen 11 callout).
  var inlineNoun: String {
    switch self {
    case .dining: "dining"
    case .subscriptions: "subscriptions"
    case .shopping: "shopping"
    case .travel: "travel"
    case .transport: "transport"
    case .smallDailySpends: "small daily spends"
    }
  }
}

// MARK: - Leak callout tier (Screen 11, dynamic copy)

enum OnboardingLeakCalloutTier {
  case none
  case low
  case mid
  case high

  /// Monthly redirect range copy (e.g. "$200–$400/mo").
  var monthlyRange: String {
    switch self {
    case .none: ""
    case .low: "$100–$200/mo"
    case .mid: "$200–$400/mo"
    case .high: "$300–$500/mo"
    }
  }

  /// 10-year compounded portfolio impact range copy (e.g. "$30,000–$60,000").
  /// Computed from `monthlyRange` * 12 * 10 with a ~7% return assumption (annuity FV ≈ 14× principal).
  var tenYearImpact: String {
    switch self {
    case .none: ""
    case .low: "$15,000–$30,000"
    case .mid: "$30,000–$60,000"
    case .high: "$45,000–$75,000"
    }
  }
}

// MARK: - Answers container

struct OnboardingQuestionnaireAnswers: Equatable {
  var goal: OnboardingGoal?
  var painPoints: Set<OnboardingPainPoint> = []
  /// Indexes (0..<5) of swipe-statements the user agreed with on Screen 5.
  var swipeStatementsAgreed: Set<Int> = []
  var holdings: Set<OnboardingHoldingType> = []
  var spendingLeaks: Set<OnboardingSpendingLeak> = []
  /// Demo-card ticker symbols selected on Screen 10.
  var demoPicks: [String] = []

  var leakCalloutTier: OnboardingLeakCalloutTier {
    switch spendingLeaks.count {
    case 0: .none
    case 1...2: .low
    case 3...4: .mid
    default: .high
    }
  }

  /// Inline copy fragment listing the leak categories the user picked, used in Screen 11.
  /// Returns "dining and subscriptions" for two picks, "dining, subscriptions and travel" for three, etc.
  var spendingLeaksInlinePhrase: String {
    let nouns = OnboardingSpendingLeak.allCases
      .filter { spendingLeaks.contains($0) }
      .map(\.inlineNoun)
    switch nouns.count {
    case 0: return ""
    case 1: return nouns[0]
    case 2: return "\(nouns[0]) and \(nouns[1])"
    default:
      let leading = nouns.dropLast().joined(separator: ", ")
      return "\(leading) and \(nouns.last ?? "")"
    }
  }
}
