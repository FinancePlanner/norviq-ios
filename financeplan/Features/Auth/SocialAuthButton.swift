import SwiftUI

struct SocialAuthButton: View {
  let provider: SocialAuthProvider
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        providerIcon
          .frame(width: 20, height: 20)

        Text(provider.title)
          .font(.subheadline.weight(.semibold))
      }
      .foregroundStyle(foregroundColor)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity)
      .background(backgroundColor)
      .clipShape(.rect(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(borderColor, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(provider.title)
    .accessibilityIdentifier("socialAuth.\(provider.rawValue)")
  }

  @ViewBuilder
  private var providerIcon: some View {
    if provider.usesSystemImage {
      Image(systemName: provider.icon)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(.white)
    } else if provider == .google {
      Image("GoogleLogo")
        .resizable()
        .interpolation(.high)
        .scaledToFit()
    } else if provider == .x {
      Image("XLogo")
        .resizable()
        .interpolation(.high)
        .scaledToFit()
    }
  }

  private var foregroundColor: Color {
    switch provider {
    case .google: .black
    case .apple, .x: .white
    }
  }

  private var backgroundColor: Color {
    switch provider {
    case .google: .white
    case .apple: .black
    case .x: Color(white: 0.08)
    }
  }

  private var borderColor: Color {
    switch provider {
    case .google: Color.black.opacity(0.12)
    case .apple, .x: Color.white.opacity(0.08)
    }
  }
}
