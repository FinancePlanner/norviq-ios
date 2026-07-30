import Foundation
import SwiftUI

/// WATCH domain eyebrows — canonical strings from docs/vigil-identity.md.
enum VigilWatch: Equatable {
  case wealth
  case wealthPlan
  case wealthImport
  case spending
  case spendingDCA
  case intelligence
  case settings(String)
  case businessRules(String)
  case reports
  case account
  case auth(String)
  case vigilActive

  var eyebrow: String {
    switch self {
    case .wealth:
      "WATCH I — WEALTH"
    case .wealthPlan:
      "WATCH I — WEALTH · PLAN"
    case .wealthImport:
      "WATCH I — WEALTH · IMPORT"
    case .spending:
      "WATCH II — SPENDING"
    case .spendingDCA:
      "WATCH II — SPENDING & DCA CAPACITY"
    case .intelligence:
      "WATCH III — INTELLIGENCE"
    case .settings(let section):
      "Settings — \(section)"
    case .businessRules(let section):
      "Business rules — \(section)"
    case .reports:
      "WATCH I — REPORTS"
    case .account:
      "Account"
    case .auth(let label):
      label
    case .vigilActive:
      "Vigil active"
    }
  }
}

enum VigilNavigationTitle {
  /// Empty nav title under Vigil (in-content header carries the label); classic keeps `title`.
  static func display(_ title: String) -> String {
    BrandTheme.current == .vigil ? "" : title
  }
}
