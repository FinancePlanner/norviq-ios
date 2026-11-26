import SwiftUI

/// The "Pro" mark on a row that leads to a Pro feature.
struct ProBadge: View {
  var body: some View {
    Text("Pro")
      .font(.caption.weight(.semibold))
      .foregroundStyle(AppTheme.Colors.tint)
  }
}
