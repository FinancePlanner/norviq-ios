import AuthenticationServices
import SwiftUI

struct SocialAuthButton: View {
  let provider: SocialAuthProvider
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  @ViewBuilder
  var body: some View {
    if provider == .apple {
      AppleSignInButton(style: appleButtonStyle, action: action)
        .id(colorScheme)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .accessibilityIdentifier("socialAuth.apple")
    } else {
      Button(action: action) {
        HStack(spacing: 10) {
          providerIcon
            .frame(width: 20, height: 20)

          Text(provider.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foregroundColor)
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(backgroundColor)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
          RoundedRectangle(cornerRadius: 12)
            .stroke(borderColor, lineWidth: 1)
        }
      }
      .buttonStyle(.plain)
      .accessibilityLabel(provider.title)
      .accessibilityIdentifier("socialAuth.\(provider.rawValue)")
    }
  }

  @ViewBuilder
  private var providerIcon: some View {
    if provider == .google {
      Image("GoogleLogo")
        .renderingMode(.original)
        .resizable()
        .interpolation(.high)
        .scaledToFit()
    } else if provider == .x {
      Image("XLogo")
        .renderingMode(.template)
        .resizable()
        .interpolation(.high)
        .scaledToFit()
        .foregroundStyle(foregroundColor)
    }
  }

  private var foregroundColor: Color {
    switch provider {
    case .google: .black
    case .x: colorScheme == .dark ? .black : .white
    case .apple: .primary
    }
  }

  private var backgroundColor: Color {
    switch provider {
    case .google: .white
    case .x: colorScheme == .dark ? .white : .black
    case .apple: .clear
    }
  }

  private var borderColor: Color {
    switch provider {
    case .google: Color.black.opacity(0.16)
    case .apple, .x: .clear
    }
  }

  private var appleButtonStyle: ASAuthorizationAppleIDButton.Style {
    colorScheme == .dark ? .white : .black
  }
}
