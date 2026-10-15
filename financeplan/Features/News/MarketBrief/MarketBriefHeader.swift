import StockPlanShared
import SwiftUI

/// Slot title, trading date and generation time, plus a "Limited sources"
/// badge when web search was unavailable for this brief, and the share menu.
struct MarketBriefHeader: View {
  let brief: MarketBriefResponse
  let isFetching: Bool
  /// Where the share menu reports "Link copied" and channel fallbacks.
  @Binding var shareToast: ToastData?
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      VStack(alignment: .leading, spacing: 4) {
        Label {
          Text(title)
        } icon: {
          Image(systemName: brief.slot == .evening ? "moon.stars.fill" : "sunrise.fill")
            .foregroundStyle(.tint)
        }
        .typography(.small, weight: .semibold)
        .accessibilityAddTraits(.isHeader)

        if let meta {
          Text(verbatim: meta)
            .typography(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Spacer(minLength: 8)

      if isFetching {
        ProgressView()
          .controlSize(.small)
      }

      if brief.degraded {
        Text("Limited sources")
          .typography(.footnote, weight: .semibold)
          .foregroundStyle(AppTheme.Colors.warningText(for: colorScheme))
          .padding(.horizontal, 8)
          .padding(.vertical, 2)
          .background(AppTheme.Colors.warning.opacity(0.14), in: .capsule)
          .accessibilityHint(Text("Written without live web sources."))
      }

      if let sharePayload = MarketBriefSharePayload(brief: brief) {
        MarketBriefShareMenu(payload: sharePayload, toast: $shareToast)
      }
    }
  }

  private var title: LocalizedStringKey {
    switch brief.slot {
    case .evening: "Market close recap"
    case .morning, nil: "Morning brief"
    }
  }

  /// "Thu, 15 Oct · 08:16", in the brief's language.
  private var meta: String? {
    let parts = [
      MarketBriefFormat.tradingDateLabel(brief.tradingDate, language: brief.language),
      MarketBriefFormat.generatedTimeLabel(brief.generatedAt, language: brief.language)
    ].compactMap(\.self)
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }
}
