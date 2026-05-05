import Foundation
import Observation
import SwiftUI

enum ReportCard: String, Codable, CaseIterable, Identifiable {
  case netWorth = "Net Worth"
  case quickStats = "Quick Stats"
  case insights = "Insights"
  case performance = "Performance"
  case allocation = "Allocation"
  case spending = "Spending"
  case budget = "Budget Tracking"
  case savings = "Savings Rate"
  case household = "Household Split"
  case cashFlow = "Cash Flow"
  
  var id: String { rawValue }
  
  var icon: String {
    switch self {
    case .netWorth: return "dollarsign.circle.fill"
    case .quickStats: return "chart.bar.fill"
    case .insights: return "lightbulb.fill"
    case .performance: return "chart.line.uptrend.xyaxis"
    case .allocation: return "chart.pie.fill"
    case .spending: return "creditcard.fill"
    case .budget: return "gauge.with.dots.needle.bottom.50percent"
    case .savings: return "banknote.fill"
    case .household: return "person.2.fill"
    case .cashFlow: return "arrow.up.arrow.down"
    }
  }
}

@Observable @MainActor
class ReportsDashboardPreferences {
  var cardOrder: [ReportCard]
  var hiddenCards: Set<ReportCard>
  
  private let orderKey = "reportsDashboardOrder"
  private let hiddenKey = "reportsDashboardHidden"
  
  init() {
    if let orderData = UserDefaults.standard.data(forKey: orderKey),
       let decoded = try? JSONDecoder().decode([ReportCard].self, from: orderData) {
      self.cardOrder = decoded
    } else {
      self.cardOrder = ReportCard.allCases
    }
    
    if let hiddenData = UserDefaults.standard.data(forKey: hiddenKey),
       let decoded = try? JSONDecoder().decode(Set<ReportCard>.self, from: hiddenData) {
      self.hiddenCards = decoded
    } else {
      self.hiddenCards = []
    }
  }
  
  func save() {
    if let orderData = try? JSONEncoder().encode(cardOrder) {
      UserDefaults.standard.set(orderData, forKey: orderKey)
    }
    if let hiddenData = try? JSONEncoder().encode(hiddenCards) {
      UserDefaults.standard.set(hiddenData, forKey: hiddenKey)
    }
  }
  
  func toggleCard(_ card: ReportCard) {
    if hiddenCards.contains(card) {
      hiddenCards.remove(card)
    } else {
      hiddenCards.insert(card)
    }
    save()
  }
  
  func moveCard(from source: IndexSet, to destination: Int) {
    cardOrder.move(fromOffsets: source, toOffset: destination)
    save()
  }
  
  func resetToDefault() {
    cardOrder = ReportCard.allCases
    hiddenCards = []
    save()
  }
  
  var visibleCards: [ReportCard] {
    cardOrder.filter { !hiddenCards.contains($0) }
  }
}
