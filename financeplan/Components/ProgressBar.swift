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
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: height / 2)
          .fill(Color.white.opacity(0.1))
          .frame(height: height)
        
        RoundedRectangle(cornerRadius: height / 2)
          .fill(color)
          .frame(width: geo.size.width * progress, height: height)
          .overlay(
            Group {
              if showPattern && isOverBudget {
                // Diagonal stripes pattern for over-budget (accessibility)
                GeometryReader { barGeo in
                  Path { path in
                    let spacing: CGFloat = 4
                    let lineWidth: CGFloat = 2
                    var x: CGFloat = -barGeo.size.height
                    while x < barGeo.size.width {
                      path.move(to: CGPoint(x: x, y: barGeo.size.height))
                      path.addLine(to: CGPoint(x: x + barGeo.size.height, y: 0))
                      x += spacing
                    }
                  }
                  .stroke(Color.white.opacity(0.3), lineWidth: 1)
                }
              }
            }
          )
          .clipShape(RoundedRectangle(cornerRadius: height / 2))
      }
    }
    .frame(height: height)
    .accessibilityLabel("Progress: \(Int(progress * 100))%")
    .accessibilityValue(isOverBudget ? "Over budget" : "\(Int((1 - progress) * 100))% remaining")
  }
}
