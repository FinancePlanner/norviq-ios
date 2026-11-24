import StockPlanShared
import SwiftUI

/// The portfolio hero. Every figure comes finished from `PortfolioHeroModel`:
/// real data in the currency the data names, or a plain caption saying why
/// there is no change or line to show.
struct PortfolioHeroCard: View {
  let heroLabel: String
  let heroSubtitle: String
  let model: PortfolioHeroModel
  let selectedTimeRange: PortfolioScreen.TimeRange
  let positionCount: Int
  let averagePositionText: String
  let cashText: String
  let onSelectTimeRange: (PortfolioScreen.TimeRange) -> Void

  private var directionColor: Color {
    switch model.direction {
    case .up: AppTheme.Colors.gain
    case .down: AppTheme.Colors.loss
    case .flat: AppTheme.Colors.foreground
    }
  }

  private var directionSymbol: String {
    switch model.direction {
    case .up: "arrow.up.right"
    case .down: "arrow.down.right"
    case .flat: "arrow.right"
    }
  }

  var body: some View {
    GlassCard(cornerRadius: AppTheme.Radius.hero) {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text(heroLabel)
            .typography(.small, weight: .semibold)
            .foregroundStyle(.secondary)

          valueBlock

          if let deltaText = model.deltaText {
            HStack(spacing: 4) {
              Image(systemName: directionSymbol)
                .accessibilityHidden(true)
              Text(verbatim: deltaText)
                .monospacedDigit()
              if let basisText = model.basisText {
                Text(verbatim: basisText)
                  .foregroundStyle(.secondary)
              }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(directionColor)
            .accessibilityElement(children: .combine)
          }

          if let asOfText = model.asOfText {
            Text(verbatim: asOfText)
              .typography(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .padding(.horizontal, 4)

        if model.points.isEmpty {
          if let historyCaption = model.historyCaption {
            Text(verbatim: historyCaption)
              .typography(.caption)
              .foregroundStyle(.secondary)
              .padding(.horizontal, 4)
          }
        } else {
          InteractiveLineChart(
            data: model.points,
            color: directionColor,
            currencyCode: model.currencyCode
          )
          .frame(minHeight: 160, maxHeight: .infinity)
          .padding(.horizontal, -12)
        }

        GlassEffectContainer(spacing: 8) {
          HStack(spacing: 8) {
            ForEach(PortfolioScreen.TimeRange.heroRanges) { range in
              PortfolioRangeButton(
                title: range.rawValue,
                isSelected: selectedTimeRange == range,
                tint: AppTheme.Colors.tint,
                action: { onSelectTimeRange(range) }
              )
            }
          }
        }

        HStack {
          PortfolioMetricPill(
            title: String(localized: "Positions"),
            value: positionCount.formatted(.number.locale(MoneyFormatter.defaultLocale)),
            tint: AppTheme.Colors.secondaryTint
          )
          PortfolioMetricPill(
            title: String(localized: "Avg / position"),
            value: averagePositionText,
            tint: AppTheme.Colors.tint
          )
          PortfolioMetricPill(
            title: String(localized: "Cash"),
            value: cashText,
            tint: .mint
          )
        }
      }
    }
    .foregroundStyle(.primary)
  }

  @ViewBuilder
  private var valueBlock: some View {
    if let valueText = model.valueText {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(verbatim: valueText)
          .typography(.displayNumber)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Text(heroSubtitle)
          .typography(.small)
          .foregroundStyle(.secondary)
      }
    } else if !model.subtotalTexts.isEmpty {
      // Holdings in several currencies: no rate to add them with, so each
      // currency keeps its own subtotal.
      VStack(alignment: .leading, spacing: 2) {
        Text(verbatim: model.subtotalTexts.joined(separator: " + "))
          .typography(.metricNumber)
          .lineLimit(2)
          .minimumScaleFactor(0.6)
        Text(heroSubtitle)
          .typography(.small)
          .foregroundStyle(.secondary)
      }
    } else {
      Text(heroSubtitle)
        .typography(.small)
        .foregroundStyle(.secondary)
    }
  }
}
