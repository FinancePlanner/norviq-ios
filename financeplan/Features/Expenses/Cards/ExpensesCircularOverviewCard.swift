import SwiftUI

struct ExpensesCircularOverviewCard: View {
  let leftAmount: Double
  let totalAmount: Double
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var progress: Double = 0

  private var targetProgress: Double {
    totalAmount > 0 ? max(0, min(1, leftAmount / totalAmount)) : 0
  }

  private var statusColor: Color {
    if leftAmount <= 0 { return AppTheme.Colors.danger }
    if targetProgress <= 0.25 { return AppTheme.Colors.warning }
    return AppTheme.Colors.tint(for: colorScheme)
  }

  var body: some View {
    VStack {
      ZStack {
        Circle()
          .stroke(AppTheme.Colors.tertiaryFill(for: colorScheme), lineWidth: 10)

        Circle()
          .trim(from: 0, to: progress)
          .stroke(statusColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
          .rotationEffect(.degrees(-90))

        VStack(spacing: 8) {
          Text("Monthly Budget")
            .typography(.small)
            .foregroundStyle(.secondary)

          Text(leftAmount.currency)
            .font(.largeTitle.weight(.semibold))
            .monospacedDigit()

          Text(leftAmount < 0 ? "Over budget" : "Remaining")
            .typography(.small, weight: .semibold)
            .foregroundStyle(statusColor)

          Text("\(targetProgress.formatted(.percent.precision(.fractionLength(0)))) of \(totalAmount.currency)")
            .typography(.small)
            .foregroundStyle(.secondary)
        }
      }
      .aspectRatio(1, contentMode: .fit)
      .frame(maxHeight: 220)
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
    }
    .accessibilityElement(children: .combine)
    .onAppear(perform: updateProgress)
    .onChange(of: targetProgress) { _, _ in updateProgress() }
  }

  private func updateProgress() {
    guard !reduceMotion else {
      progress = targetProgress
      return
    }
    withAnimation(AppMotion.dataReveal) { progress = targetProgress }
  }
}
