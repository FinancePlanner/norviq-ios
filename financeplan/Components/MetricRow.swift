import SwiftUI

/// A label/value row, optionally carrying explanatory context behind a tap.
///
/// The app had roughly fifteen near-identical row structs, most of them inside
/// `StockInsightsViews.swift`, and several rendered a permanent second line of
/// grey prose under every value. On a twelve-row card that reads as a wall of
/// text with numbers hidden in it, so the context moves behind an affordance
/// instead: the row shows label and value, and `caption` — when there is one —
/// is reachable through the trailing glyph.
///
/// `caption` is deliberately optional. The struct this replaced took a
/// non-optional `detail`, which is why every metric had to invent one.
struct MetricRow: View {
  let title: String
  let value: String
  var caption: String?
  var onShowCaption: (() -> Void)?

  private var isInteractive: Bool { caption != nil && onShowCaption != nil }

  var body: some View {
    if isInteractive {
      Button { onShowCaption?() } label: { rowContent }
        .buttonStyle(.plain)
        .accessibilityHint("Shows how this metric compares.")
    } else {
      rowContent
    }
  }

  private var rowContent: some View {
    HStack(spacing: 12) {
      Text(title)
        .typography(.small)
        .foregroundStyle(.primary)

      Spacer(minLength: 12)

      Text(value)
        .typography(.small, weight: .semibold)
        .monospacedDigit()
        .foregroundStyle(.primary)

      if isInteractive {
        Image(systemName: "info.circle")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
      }
    }
    // Keeps the whole row a valid 44pt target rather than just the glyph.
    .frame(minHeight: 44)
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
  }
}

/// The context a `MetricRow` reveals on tap.
///
/// Modelled as a payload rather than a `Bool` plus a separate optional so the
/// sheet cannot open before the data behind it is ready.
struct MetricCaption: Identifiable {
  let id: String
  let title: String
  let value: String
  let caption: String
}

struct MetricCaptionSheet: View {
  let metric: MetricCaption

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 4) {
          Text(metric.title)
            .typography(.caption)
            .foregroundStyle(.secondary)

          Text(metric.value)
            .typography(.title, weight: .semibold)
            .monospacedDigit()
        }

        Text(metric.caption)
          .typography(.body)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        Spacer()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(20)
      .background(AppTheme.Colors.pageBackground.ignoresSafeArea())
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium])
  }
}
