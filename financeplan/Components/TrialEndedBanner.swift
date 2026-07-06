import SwiftUI

/// Persistent banner shown at the top of Home once the user's free trial has ended
/// and they have not subscribed. Tapping "Subscribe" opens the in-app paywall
/// (StoreKit via RevenueCat) — the App Review-visible purchase path after trial expiry.
///
/// Only rendered when `BillingManager.shouldShowTrialEndedBanner` is true, so it never
/// appears for never-trialed free users or active subscribers.
struct TrialEndedBanner: View {
  let onSubscribe: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Image(systemName: "crown.fill")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.warning)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text("Your free trial has ended")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)
          .fixedSize(horizontal: false, vertical: true)

        Text("Subscribe to keep your Pro features.")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Button(action: onSubscribe) {
        Text("Subscribe")
          .font(.footnote.weight(.bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background(AppTheme.Colors.tint(for: colorScheme), in: Capsule())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("trialEndedBanner.subscribe")
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity)
    .appGlassEffect(.rect(cornerRadius: 16), tint: AppTheme.Colors.warning.opacity(0.14))
    .clipShape(.rect(cornerRadius: 16))
    .padding(.horizontal, 12)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Your free trial has ended. Subscribe to keep your Pro features.")
    .accessibilityIdentifier("trialEndedBanner")
  }
}
