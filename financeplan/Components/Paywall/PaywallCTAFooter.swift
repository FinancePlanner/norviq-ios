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
  var restoreStatusMessage: String?
  var restoreStatusIsSuccess = false
  var privacyURL: URL? = Constants.Norviq.privacyPolicyUrl
  var termsURL: URL? = Constants.Norviq.termsOfUseUrl
  var disclosureText: String?

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
        disclosureLabel
        skipButton
        errorLabel
        restoreStatusLabel

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
            Button("Terms of Use") {
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
      .maxContentWidth(regularSizeClass: ContentWidth.marketing)
      .frame(maxWidth: .infinity)
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
  private var disclosureLabel: some View {
    if let disclosureText, !disclosureText.isEmpty {
      Text(disclosureText)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
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

  @ViewBuilder
  private var restoreStatusLabel: some View {
    if let restoreStatusMessage, !restoreStatusMessage.isEmpty {
      Label(
        restoreStatusMessage,
        systemImage: restoreStatusIsSuccess ? "checkmark.circle.fill" : "info.circle"
      )
      .font(.caption)
      .foregroundStyle(
        restoreStatusIsSuccess
          ? AppTheme.Colors.success
          : AppTheme.Colors.tint(for: colorScheme)
      )
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
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
