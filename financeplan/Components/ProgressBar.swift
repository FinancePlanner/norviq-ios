import SwiftUI

struct ProgressBar: View {
  let value: Double
  let total: Double
  let color: Color
  let height: CGFloat
  let showPattern: Bool
  
  init(value: Double, total: Double, color: Color = AppTheme.Colors.tint, height: CGFloat = 6, showPattern: Bool = true) {
    self.value = value
    self.total = total
    self.color = color
    self.height = height
    self.showPattern = showPattern
  }
  
  /// Unclamped, so `isOverBudget` can actually become true.
  private var rawProgress: Double {
    guard total > 0 else { return 0 }
    return value / total
  }

  /// Clamped, for drawing.
  private var progress: Double {
    min(max(rawProgress, 0), 1.0)
  }

  private var isOverBudget: Bool {
    rawProgress > 1.0
  }

  var body: some View {
    // Width-based rather than scaleEffect: scaling a Capsule on x squashes its
    // end caps into ellipses, so a bar at 20% had visibly flatter ends than one
    // at 90%.
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule()
          // Was Color.white.opacity(0.1) — invisible against a light page, so in
          // light mode every bar in the app rendered with no track at all.
          .fill(AppTheme.Colors.tertiaryFill)

        Capsule()
          .fill(color)
          .frame(width: max(proxy.size.width * progress, progress > 0 ? height : 0))
          .overlay {
            if showPattern && isOverBudget {
              DiagonalStripes()
                .stroke(AppTheme.Colors.onTint.opacity(0.35), lineWidth: 1)
                .clipShape(.capsule)
            }
          }
      }
    }
    .frame(height: height)
    .accessibilityLabel("Progress: \(Int(rawProgress * 100))%")
    .accessibilityValue(isOverBudget ? "Over budget" : "\(Int((1 - progress) * 100))% remaining")
  }
}

private struct DiagonalStripes: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let spacing: CGFloat = 4
    var x: CGFloat = -rect.height
    while x < rect.width {
      path.move(to: CGPoint(x: x, y: rect.height))
      path.addLine(to: CGPoint(x: x + rect.height, y: 0))
      x += spacing
    }
    return path
  }
}
