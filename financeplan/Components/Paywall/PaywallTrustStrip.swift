import SwiftUI

/// Horizontal trust-building strip showing security and cancellation assurances.
struct PaywallTrustStrip: View {
  struct Item: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
  }

  var items: [Item] = [
    Item(icon: "lock.shield.fill", text: "Bank-level encryption"),
    Item(icon: "clock.fill", text: "Cancel anytime"),
    Item(icon: "creditcard.fill", text: "Charged after trial"),
  ]

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
