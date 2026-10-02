import Foundation
import UIKit

#if canImport(FacebookLogin)
  import FacebookCore
  import FacebookLogin
#endif

/// The Facebook SDK seam. Available only when the build carries the SDK and
/// both `FacebookAppID` and `FacebookClientToken` are set (build settings
/// FACEBOOK_APP_ID / FACEBOOK_CLIENT_TOKEN); otherwise the SDK is never
/// started and the Friends tab leaves the Facebook row out.
enum FacebookConnect {
  enum Failure: Error { case cancelled, unavailable, noToken }

  static var isAvailable: Bool {
    #if canImport(FacebookLogin)
      return configuredValue("FacebookAppID") != nil && configuredValue("FacebookClientToken") != nil
    #else
      return false
    #endif
  }

  /// Starts the SDK at launch, and only when it's configured: without an app
  /// ID it would complain about the missing URL scheme on every launch.
  static func applicationDidFinishLaunching(
    _ application: UIApplication,
    launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) {
    #if canImport(FacebookLogin)
      guard isAvailable else { return }
      ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
    #endif
  }

  /// Hands the Facebook app's login callback (`fb<app id>://…`) to the SDK.
  /// Returns false for every other URL, which keeps its usual routing.
  static func handle(_ url: URL) -> Bool {
    #if canImport(FacebookLogin)
      guard isAvailable, let appID = configuredValue("FacebookAppID"),
            url.scheme?.lowercased() == "fb\(appID)".lowercased() else { return false }
      return ApplicationDelegate.shared.application(UIApplication.shared, open: url, options: [:])
    #else
      return false
    #endif
  }

  /// Limited Login with the friends permission: no tracking prompt, and the
  /// server verifies the token. Returns the OIDC token and the nonce it was
  /// asked for.
  static func logIn() async throws -> (token: String, nonce: String) {
    #if canImport(FacebookLogin)
      guard isAvailable else { throw Failure.unavailable }
      let nonce = UUID().uuidString + UUID().uuidString
      guard let configuration = LoginConfiguration(
        permissions: ["public_profile", "user_friends"],
        tracking: .limited,
        nonce: nonce
      ) else {
        throw Failure.unavailable
      }
      return try await withCheckedThrowingContinuation { continuation in
        LoginManager().logIn(configuration: configuration) { result in
          switch result {
          case .cancelled:
            continuation.resume(throwing: Failure.cancelled)
          case let .failed(error):
            continuation.resume(throwing: error)
          case .success:
            if let token = AuthenticationToken.current?.tokenString {
              continuation.resume(returning: (token, nonce))
            } else {
              continuation.resume(throwing: Failure.noToken)
            }
          }
        }
      }
    #else
      throw Failure.unavailable
    #endif
  }

  /// Forgets the SDK's local login, so the next connect asks again.
  static func logOut() {
    #if canImport(FacebookLogin)
      guard isAvailable else { return }
      LoginManager().logOut()
    #endif
  }

  /// An Info.plist value that was actually set: an empty build setting
  /// expands to "", and a missing one would leave "$(…)" behind.
  private static func configuredValue(_ key: String) -> String? {
    let value = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let value, !value.isEmpty, !value.hasPrefix("$(") else { return nil }
    return value
  }
}
