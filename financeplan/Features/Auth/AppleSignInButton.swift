import AuthenticationServices
import SwiftUI

/// Apple's system-provided authorization control, bridged to the app's
/// existing web OAuth action.
struct AppleSignInButton: UIViewRepresentable {
  let style: ASAuthorizationAppleIDButton.Style
  let action: () -> Void

  func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
    let button = ASAuthorizationAppleIDButton(type: .continue, style: style)
    button.cornerRadius = 12
    button.accessibilityIdentifier = "socialAuth.apple"
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return button
  }

  func updateUIView(_ button: ASAuthorizationAppleIDButton, context: Context) {}
}
