import SwiftUI

/// Kicker header that groups paywall feature rows under one of the three
/// Vigil domain groups (Wealth / Spending / Intelligence).
struct PaywallWatchHeader: View {
  let title: String

  var body: some View {
    Text(title)
      .font(.caption.weight(.semibold))
      .tracking(1.4)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityAddTraits(.isHeader)
  }
}

/// One comparison row: feature name plus Free / Pro inclusion.
struct PaywallFeatureRow: View {
  let row: PaywallCatalog.Row

  var body: some View {
    HStack(spacing: 12) {
      Text(row.title)
        .font(.body)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)

      inclusionMark(included: row.includedInFree)
        .frame(width: 44)
      inclusionMark(included: row.includedInPro)
        .frame(width: 44)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
  }

  private var accessibilityLabel: String {
    let free = row.includedInFree ? "included in Free" : "not in Free"
    let pro = row.includedInPro ? "included in Pro" : "not in Pro"
    return "\(row.title), \(free), \(pro)"
  }

  private func inclusionMark(included: Bool) -> some View {
    Image(systemName: included ? "checkmark" : "minus")
      .font(.body.weight(.semibold))
      .foregroundStyle(included ? Color.primary : Color.secondary.opacity(0.45))
      .frame(maxWidth: .infinity)
      .accessibilityHidden(true)
  }
}

/// Grouped Free / Pro comparison used on paywalls and subscription settings.
struct PaywallComparisonTable: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      ForEach(PaywallCatalog.groups) { group in
        VStack(alignment: .leading, spacing: 8) {
          PaywallWatchHeader(title: group.watch.title)

          VStack(spacing: 0) {
            columnHeader
            ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
              PaywallFeatureRow(row: row)
              if index < group.rows.count - 1 {
                Divider().padding(.leading, 16)
              }
            }
          }
          .background(Color(.secondarySystemBackground))
          .clipShape(.rect(cornerRadius: 10))
        }
      }
    }
  }

  private var columnHeader: some View {
    HStack(spacing: 12) {
      Text("Feature")
        .frame(maxWidth: .infinity, alignment: .leading)
      Text("Free")
        .frame(width: 44)
      Text("Pro")
        .frame(width: 44)
    }
    .font(.caption.weight(.semibold))
    .foregroundStyle(.secondary)
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Feature comparison, Free and Pro")
  }
}
