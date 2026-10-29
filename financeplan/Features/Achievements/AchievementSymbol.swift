import SwiftUI
import UIKit

/// The server names icons by SF Symbol. A name this OS doesn't have would
/// render as nothing, so fall back to a rosette.
enum AchievementSymbol {
  static let fallback = "rosette"

  static func name(for iconKey: String) -> String {
    UIImage(systemName: iconKey) == nil ? fallback : iconKey
  }
}

/// Bronze / silver / gold presentation. An empty tier is a single-tier
/// achievement and has no label.
enum AchievementTierStyle {
  static func rank(_ tier: String) -> Int {
    switch tier {
    case "gold": 3
    case "silver": 2
    case "bronze": 1
    default: 0
    }
  }

  static func label(_ tier: String) -> LocalizedStringKey? {
    switch tier {
    case "gold": "Gold"
    case "silver": "Silver"
    case "bronze": "Bronze"
    default: nil
    }
  }

  static func color(_ tier: String) -> Color {
    switch tier {
    case "gold": Color(red: 1.00, green: 0.84, blue: 0.00)
    case "silver": Color(red: 0.65, green: 0.70, blue: 0.75)
    case "bronze": Color(red: 0.80, green: 0.50, blue: 0.20)
    default: AppTheme.Colors.tint
    }
  }
}
