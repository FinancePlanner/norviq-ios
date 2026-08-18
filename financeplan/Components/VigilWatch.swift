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
      "Wealth"
    case .wealthPlan:
      "Wealth · Plan"
    case .wealthImport:
      "Wealth · Import"
    case .spending:
      "Spending"
    case .spendingDCA:
      "Spending · DCA"
    case .intelligence:
      "Intelligence"
    case .settings(let section):
      "Settings · \(section)"
    case .businessRules(let section):
      "Rules · \(section)"
    case .reports:
      "Reports"
    case .account:
      "Account"
    case .auth(let label):
      label
    case .vigilActive:
      "Vigil"
    }
  }
}

enum VigilNavigationTitle {
  /// Empty nav title under Vigil (in-content header carries the label); classic keeps `title`.
  static func display(_ title: String) -> String {
    BrandTheme.current == .vigil ? "" : title
  }
}
