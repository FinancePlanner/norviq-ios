import SwiftUI

/// Horizontal trust-building strip showing security and cancellation assurances.
struct PaywallTrustStrip: View {
  struct Item: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
  }

  /// When true, the third item references billing after a free trial (annual plan only).
  var showsTrialChargeMessage: Bool = false

  private var items: [Item] {
    [
      Item(icon: "lock.shield.fill", text: "Bank-level encryption"),
      Item(icon: "clock.fill", text: "Cancel anytime"),
      Item(
        icon: "creditcard.fill",
        text: showsTrialChargeMessage ? "Charged after trial" : "Secure billing"
      ),
    ]
  }

  var body: some View {
    HStack(spacing: 14) {
      ForEach(items) { item in
        VStack(spacing: 4) {
          Image(systemName: item.icon)
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text(item.text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
      }
    }
    .padding(.top, 4)
  }
}
