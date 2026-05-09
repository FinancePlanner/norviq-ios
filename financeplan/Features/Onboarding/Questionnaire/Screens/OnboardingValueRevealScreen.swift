import Charts
import SwiftUI

/// Screen 11 — value delivery + viral moment.
/// Mini-load (~1.5s) → reveals donut + 10-yr projection + dynamic leak callout.
struct OnboardingValueRevealScreen: View {
  let demoPicks: [String]
  let leakTier: OnboardingLeakCalloutTier
  let leakInlinePhrase: String
  let onSavePlan: () -> Void

  @State private var revealed = false
  @Environment(\.colorScheme) private var colorScheme

  private var pickedTickers: [OnboardingDemoTicker] {
    demoPicks.compactMap { symbol in
      OnboardingDemoTickers.all.first { $0.symbol == symbol }
    }
  }

  var body: some View {
    Group {
      if revealed {
        revealContent
          .transition(.opacity)
      } else {
        loadingState
          .transition(.opacity)
      }
    }
    .onAppear {
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(1500))
        withAnimation(.easeInOut(duration: 0.4)) {
          revealed = true
        }
      }
    }
  }

  // MARK: - Loading

  private var loadingState: some View {
    VStack(spacing: 24) {
      Spacer()

      ZStack {
        Circle()
          .fill(AppTheme.Colors.tintSoft(for: colorScheme))
          .frame(width: 96, height: 96)
        Image(systemName: "chart.pie.fill")
          .font(.largeTitle.bold())
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
      }

      Text("Building your starter dashboard…")
        .typography(.title, weight: .bold)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      Spacer()
    }
  }

  // MARK: - Reveal

  private var revealContent: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 18) {
          headlineBlock
          allocationCard
          projectionCard
          if leakTier != .none {
            leakCard
          }
          shareLink
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }

      OnboardingActionBar(
        primaryTitle: "Save my starter plan",
        showsArrow: true,
        onPrimary: onSavePlan
      )
    }
  }

  private var headlineBlock: some View {
    VStack(spacing: 8) {
      Text("Here's your starter plan.")
        .typography(.title, weight: .bold)
        .multilineTextAlignment(.center)

      Text("Based on what you picked. Real you, real numbers — once you're in.")
        .typography(.label)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
    }
    .padding(.top, 8)
  }

  // MARK: - Allocation card (donut + legend)

  private var allocationCard: some View {
    GlassCard(cornerRadius: 22) {
      VStack(alignment: .leading, spacing: 14) {
        Text("Your starter portfolio")
          .typography(.caption, weight: .semibold)
          .foregroundStyle(.secondary)

        HStack(alignment: .center, spacing: 18) {
          AllocationDonutChart(tickers: pickedTickers)
            .frame(width: 110, height: 110)

          VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(pickedTickers.enumerated()), id: \.element.symbol) { offset, ticker in
              HStack(spacing: 10) {
                Circle()
                  .fill(AllocationDonutChart.color(for: offset, in: colorScheme))
                  .frame(width: 10, height: 10)
                Text(ticker.symbol)
                  .typography(.small, weight: .semibold)
                Spacer()
                Text(equalWeightPercent(count: pickedTickers.count))
                  .typography(.small)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
      }
      .padding(.vertical, 4)
    }
  }

  private func equalWeightPercent(count: Int) -> String {
    guard count > 0 else { return "0%" }
    let pct = 100.0 / Double(count)
    return String(format: "%.1f%%", pct)
  }

  // MARK: - Projection card

  private var projectionCard: some View {
    GlassCard(cornerRadius: 22) {
      VStack(alignment: .leading, spacing: 10) {
        Text("If you put $10,000 in today,")
          .typography(.caption, weight: .semibold)
          .foregroundStyle(.secondary)

        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text("≈ $19,700")
            .typography(.hero, weight: .bold)
            .foregroundStyle(AppTheme.Colors.success)

          Text("in 10 years*")
            .typography(.label, weight: .semibold)
            .foregroundStyle(.secondary)
        }

        Text("*Based on the historical S&P 500 average of ~7% annual return — past performance doesn't guarantee future results.")
          .typography(.nano)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.vertical, 4)
    }
  }

  // MARK: - Leak callout

  private var leakCard: some View {
    GlassCard(cornerRadius: 22) {
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 8) {
          Image(systemName: "drop.degreesign")
            .font(.title3)
            .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
          Text("Money you could find from spending")
            .typography(.label, weight: .bold)
        }

        Text(calloutBody)
          .typography(.small)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 14) {
          metricChip(value: leakTier.monthlyRange, label: "redirected / mo")
          metricChip(value: leakTier.tenYearImpact, label: "in 10 years")
        }
      }
      .padding(.vertical, 4)
    }
  }

  private var calloutBody: String {
    if leakInlinePhrase.isEmpty {
      return "Tracking your top spending categories helps people redirect real money into investments."
    }
    return "Tracking \(leakInlinePhrase) helps people redirect real money into investments."
  }

  private func metricChip(value: String, label: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value)
        .typography(.label, weight: .bold)
        .foregroundStyle(AppTheme.Colors.success)
      Text(label)
        .typography(.nano)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 10)
    .padding(.horizontal, 14)
    .background(AppTheme.Colors.tintSoft(for: colorScheme))
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }

  // MARK: - Share

  private var shareLink: some View {
    let summary = shareSummary
    return ShareLink(
      item: ShareURLBuilder.app(),
      subject: Text("My Norviqa starter plan"),
      message: Text(summary),
      preview: SharePreview(
        "My Norviqa starter plan",
        image: Image(systemName: "chart.line.uptrend.xyaxis")
      )
    ) {
      HStack(spacing: 8) {
        Image(systemName: "square.and.arrow.up")
        Text("Share this plan")
          .typography(.small, weight: .semibold)
      }
      .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
      .padding(.vertical, 10)
    }
  }

  private var shareSummary: String {
    let symbols = demoPicks.joined(separator: ", ")
    return "My Norviq starter plan: \(symbols). $10k → ≈$19,700 in 10 years (7% blended)."
  }
}

// MARK: - Donut chart

private struct AllocationDonutChart: View {
  let tickers: [OnboardingDemoTicker]
  @Environment(\.colorScheme) private var colorScheme

  static func color(for index: Int, in scheme: ColorScheme) -> Color {
    let palette: [Color] = [
      AppTheme.Colors.tint(for: scheme),
      AppTheme.Colors.secondaryTint(for: scheme),
      AppTheme.Colors.success
    ]
    return palette[index % palette.count]
  }

  var body: some View {
    Chart {
      ForEach(Array(tickers.enumerated()), id: \.element.symbol) { offset, ticker in
        SectorMark(
          angle: .value("Weight", 1.0),
          innerRadius: .ratio(0.62),
          angularInset: 2
        )
        .foregroundStyle(Self.color(for: offset, in: colorScheme))
        .annotation(position: .overlay) {
          EmptyView()
        }
        .accessibilityLabel(ticker.symbol)
      }
    }
    .chartLegend(.hidden)
  }
}
