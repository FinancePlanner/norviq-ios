import StockPlanShared
import SwiftUI

enum SocialAuthProvider: String, CaseIterable, Identifiable {
  case apple
  case google
  case x

  var id: String { rawValue }

  var title: String {
    switch self {
    case .apple: "Continue with Apple"
    case .google: "Continue with Google"
    case .x: "Continue with X"
    }
  }

  var platformName: String {
    switch self {
    case .apple: "Apple"
    case .google: "Google"
    case .x: "X"
    }
  }

  var oauthProvider: OAuthProviderKind? {
    switch self {
    case .apple: .apple
    case .google: .google
    case .x: .x
    }
  }

  var icon: String {
    switch self {
    case .apple: "apple.logo"
    case .google: "GoogleLogo"
    case .x: "XLogo"
    }
  }

  var usesSystemImage: Bool {
    switch self {
    case .apple: true
    case .google, .x: false
    }
  }
}
