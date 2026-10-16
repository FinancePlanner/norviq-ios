import StockPlanShared
import SwiftUI

extension MarketBriefDirection {
  /// The app's gain / loss tokens, which already switch on the colour scheme.
  func color(for scheme: ColorScheme) -> Color {
    switch self {
    case .up: AppTheme.Colors.successText(for: scheme)
    case .down: AppTheme.Colors.dangerText(for: scheme)
    case .flat: AppTheme.Colors.secondaryText
    }
  }

  /// ▲ / ▼ / –. The percentage itself is unsigned; this carries the sign.
  var systemImage: String {
    switch self {
    case .up: "arrowtriangle.up.fill"
    case .down: "arrowtriangle.down.fill"
    case .flat: "minus"
    }
  }
}
