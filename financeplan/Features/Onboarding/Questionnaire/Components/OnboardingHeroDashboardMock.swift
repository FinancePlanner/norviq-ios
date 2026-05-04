import SwiftUI

/// Static "fake dashboard" graphic shown on the Welcome screen.
/// Standalone — does NOT render `DashboardRoot` (no auth/data at this point in the flow).
struct OnboardingHeroDashboardMock: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(spacing: 12) {
      heroCard
      HStack(spacing: 12) {
        donutCard
        spendTrendCard
      }
    }
    .padding(.horizontal, 16)
  }

  private var heroCard: some View {
    GlassCard(cornerRadius: 24) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Net worth")
          .typography(.caption)
          .foregroundStyle(.secondary)
        Text("$48,720.50")
          .typography(.title, weight: .bold)
        HStack(spacing: 6) {
          Image(systemName: "arrow.up.right")
            .font(.caption.weight(.bold))
          Text("+$1,840 this month")
            .typography(.small, weight: .semibold)
        }
        .foregroundStyle(AppTheme.Colors.success)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 4)
    }
  }

  private var donutCard: some View {
    GlassCard(cornerRadius: 22) {
      VStack(alignment: .leading, spacing: 10) {
        Text("Allocation")
          .typography(.caption)
          .foregroundStyle(.secondary)
        ZStack {
          Circle()
            .trim(from: 0.0, to: 0.42)
            .stroke(AppTheme.Colors.tint(for: colorScheme), lineWidth: 8)
            .rotationEffect(.degrees(-90))
          Circle()
            .trim(from: 0.42, to: 0.72)
            .stroke(AppTheme.Colors.secondaryTint(for: colorScheme), lineWidth: 8)
            .rotationEffect(.degrees(-90))
          Circle()
            .trim(from: 0.72, to: 1.0)
            .stroke(AppTheme.Colors.success, lineWidth: 8)
            .rotationEffect(.degrees(-90))
          Text("3")
            .typography(.label, weight: .bold)
        }
        .frame(height: 64)
        .frame(maxWidth: .infinity)
      }
      .padding(.vertical, 4)
    }
  }

  private var spendTrendCard: some View {
    GlassCard(cornerRadius: 22) {
      VStack(alignment: .leading, spacing: 10) {
        Text("This month")
          .typography(.caption)
          .foregroundStyle(.secondary)
        Text("$2,184")
          .typography(.label, weight: .bold)
        SparklinePath(values: [320, 280, 410, 372, 290, 340, 412, 384, 280, 410])
          .stroke(AppTheme.Colors.tint(for: colorScheme), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
          .frame(height: 28)
      }
      .padding(.vertical, 4)
    }
  }
}

/// Tiny line-chart shape used by the hero mock and demo ticker cards.
struct SparklinePath: Shape {
  let values: [Double]

  func path(in rect: CGRect) -> Path {
    var path = Path()
    guard values.count > 1 else { return path }

    let minV = values.min() ?? 0
    let maxV = values.max() ?? 1
    let range = max(maxV - minV, 0.0001)
    let stepX = rect.width / CGFloat(values.count - 1)

    for (i, value) in values.enumerated() {
      let x = stepX * CGFloat(i)
      let normalised = (value - minV) / range
      let y = rect.height - CGFloat(normalised) * rect.height
      if i == 0 {
        path.move(to: CGPoint(x: x, y: y))
      } else {
        path.addLine(to: CGPoint(x: x, y: y))
      }
    }
    return path
  }
}

#Preview {
  ZStack {
    MeshGradientBackground().ignoresSafeArea()
    OnboardingHeroDashboardMock()
  }
}
