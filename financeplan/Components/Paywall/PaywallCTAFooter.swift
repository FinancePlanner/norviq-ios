import SwiftUI

/// Sticky bottom CTA footer for paywall screens.
/// Contains the primary purchase button, skip link, restore link, and legal links.
struct PaywallCTAFooter: View {
  let ctaTitle: String
  var isLoading: Bool = false
  var isDisabled: Bool = false
  let onPurchase: () -> Void

  var skipTitle: String? = "Continue with Free"
  var onSkip: (() -> Void)?

  var onRestore: (() -> Void)?
  var isRestoring: Bool = false

  var errorMessage: String?
  var privacyURL: URL? = URL(string: "https://your-privacy-policy-url.com") // TODO: Replace with real URL
  var termsURL: URL?

  /// When true, adds a fade gradient above the bar and a solid background.
  /// Use for sticky-positioned footers. Set false for inline footers in scroll content.
  var isSticky: Bool = true

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.openURL) private var openURL

  var body: some View {
    VStack(spacing: 0) {
      if isSticky {
        LinearGradient(
          colors: [
            AppTheme.Colors.pageBackground(for: colorScheme).opacity(0),
            AppTheme.Colors.pageBackground(for: colorScheme),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
        .frame(height: 24)
      }

      VStack(spacing: 12) {
        purchaseButton
        skipButton
        errorLabel

        HStack(spacing: 16) {
          restoreButton

          if let privacyURL {
            Text("•").foregroundStyle(.tertiary)
            Button("Privacy Policy") {
              openURL(privacyURL)
            }
          }

          if let termsURL {
            Text("•").foregroundStyle(.tertiary)
            Button("Terms of Service") {
              openURL(termsURL)
            }
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 24)
      .padding(.bottom, isSticky ? 32 : 16)
      .padding(.top, 8)
      .background(isSticky ? AppTheme.Colors.pageBackground(for: colorScheme) : .clear)
    }
  }

  // MARK: - Subviews

  private var purchaseButton: some View {
    Button(action: onPurchase) {
      HStack(spacing: 10) {
        if isLoading {
          ProgressView().tint(.white)
        }
        Text(isLoading ? "Purchasing..." : ctaTitle)
          .font(.headline.weight(.semibold))
          .frame(maxWidth: .infinity)
      }
      .padding(.vertical, 16)
      .foregroundStyle(.white)
      .background(
        AppTheme.Colors.premiumGradient(for: colorScheme),
        in: Capsule()
      )
      .shadow(
        color: AppTheme.Colors.tint(for: colorScheme).opacity(0.3),
        radius: 10, x: 0, y: 5
      )
    }
    .buttonStyle(PressEffectStyle())
    .disabled(isLoading || isDisabled)
    .opacity(isDisabled ? 0.5 : 1.0)
  }

  @ViewBuilder
  private var skipButton: some View {
    if let skipTitle, let onSkip {
      Button(skipTitle, action: onSkip)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }
  }

  @ViewBuilder
  private var errorLabel: some View {
    if let errorMessage, !errorMessage.isEmpty {
      Text(errorMessage)
        .font(.caption)
        .foregroundStyle(AppTheme.Colors.danger)
        .multilineTextAlignment(.center)
    }
  }

  private var restoreButton: some View {
    Button {
      onRestore?()
    } label: {
      HStack(spacing: 6) {
        if isRestoring {
          ProgressView().scaleEffect(0.7)
        }
        Text("Restore Purchases")
      }
    }
  }
}
