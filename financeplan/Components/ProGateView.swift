import SwiftUI

/// Wraps content that requires a Pro subscription.
/// Free users see the content blurred with an upgrade prompt overlay.
/// Trial and Pro users see the content normally.
struct ProGateView<Content: View>: View {
    let billingManager: BillingManager
    let content: Content

    @Environment(\.colorScheme) private var colorScheme
    @State private var showPaywall = false

    init(billingManager: BillingManager, @ViewBuilder content: () -> Content) {
        self.billingManager = billingManager
        self.content = content()
    }

    var body: some View {
        if billingManager.isPro {
            content
        } else {
            content
                .blur(radius: 8)
                .overlay(overlay)
                .allowsHitTesting(false)
                .overlay(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { showPaywall = true }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("Unlock Pro feature")
                        .accessibilityIdentifier("proGate.lockedOverlay")
                )
                .sheet(isPresented: $showPaywall) {
                    PaywallView(billingManager: billingManager)
                }
        }
    }

    private var overlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))

            Text("Pro Feature")
                .typography(.title, weight: .bold)
                .accessibilityIdentifier("proGate.title")

            Text("Subscribe to unlock this view.\nFree trial available.")
                .typography(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Unlock Pro") { showPaywall = true }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("proGate.unlockButton")
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .allowsHitTesting(true)
        .accessibilityIdentifier("proGate.overlay")
    }
}
