import SwiftUI
import StockPlanShared

extension View {
  func appGradientAccent(for colorScheme: ColorScheme) -> some View {
    self.overlay(
      LinearGradient(
        colors: [
          Color.white.opacity(0.3),
          Color.clear
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
  }
  
  func cardGradientBackground(for colorScheme: ColorScheme) -> some View {
    self.background(
      LinearGradient(
        colors: [
          Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1),
          Color.white.opacity(colorScheme == .dark ? 0.02 : 0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
  }
  
  func pillarGradient(_ pillar: BudgetPillar, for colorScheme: ColorScheme) -> some View {
    self.background(
      LinearGradient(
        colors: [
          pillar.color(for: colorScheme).opacity(0.3),
          pillar.color(for: colorScheme).opacity(0.1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
  }
}
