import SwiftUI

struct ProgressBar: View {
  let value: Double
  let total: Double
  let color: Color
  let height: CGFloat
  let showPattern: Bool
  
  init(value: Double, total: Double, color: Color = .blue, height: CGFloat = 6, showPattern: Bool = true) {
    self.value = value
    self.total = total
    self.color = color
    self.height = height
    self.showPattern = showPattern
  }
  
  private var progress: Double {
    guard total > 0 else { return 0 }
    return min(value / total, 1.0)
  }
  
  private var isOverBudget: Bool {
    progress > 1.0
  }
  
  var body: some View {
    ZStack(alignment: .leading) {
      Capsule()
        .fill(Color.white.opacity(0.1))
        .frame(height: height)
      
      Capsule()
        .fill(color)
        .frame(height: height)
        .scaleEffect(x: progress, y: 1.0, anchor: .leading)
        .overlay {
          if showPattern && isOverBudget {
            DiagonalStripes()
              .stroke(Color.white.opacity(0.3), lineWidth: 1)
              .clipShape(.capsule)
          }
        }
    }
    .frame(height: height)
    .accessibilityLabel("Progress: \(Int(progress * 100))%")
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
