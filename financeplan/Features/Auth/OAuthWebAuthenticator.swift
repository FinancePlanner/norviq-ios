import AuthenticationServices
import Foundation
import UIKit

enum OAuthWebAuthenticationError: LocalizedError {
  case unableToStart
  case cancelled
  case invalidCallback
  case missingCode
  case missingState
  case invalidAuthorizationURL

  var errorDescription: String? {
    switch self {
    case .unableToStart:
      return "Could not start OAuth sign in."
    case .cancelled:
      return "OAuth sign in was cancelled."
    case .invalidCallback:
      return "OAuth callback was invalid."
    case .missingCode:
      return "OAuth callback did not return an authorization code."
    case .missingState:
      return "OAuth callback did not return state."
    case .invalidAuthorizationURL:
      return "OAuth authorization URL is invalid."
    }
  }
}

protocol OAuthWebAuthenticating: AnyObject {
  @MainActor
  func authenticate(url: URL, callbackScheme: String) async throws -> URL
}

final class OAuthWebAuthenticator: NSObject, OAuthWebAuthenticating {
  private var session: ASWebAuthenticationSession?
  private var contextProvider: OAuthPresentationContextProvider?

  @MainActor
  func authenticate(url: URL, callbackScheme: String) async throws -> URL {
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
          self?.session = nil
          self?.contextProvider = nil

          if let error = error as? ASWebAuthenticationSessionError,
             error.code == .canceledLogin {
            continuation.resume(throwing: OAuthWebAuthenticationError.cancelled)
            return
          }

          if let error {
            continuation.resume(throwing: error)
            return
          }

          guard let callbackURL else {
            continuation.resume(throwing: OAuthWebAuthenticationError.invalidCallback)
            return
          }

          continuation.resume(returning: callbackURL)
        }

        let contextProvider = OAuthPresentationContextProvider()
        self.contextProvider = contextProvider
        session.presentationContextProvider = contextProvider
        session.prefersEphemeralWebBrowserSession = true

        self.session = session

        guard session.start() else {
          self.session = nil
          self.contextProvider = nil
          continuation.resume(throwing: OAuthWebAuthenticationError.unableToStart)
          return
        }
      }
    } onCancel: { [weak self] in
      Task { @MainActor in
        self?.session?.cancel()
        self?.session = nil
        self?.contextProvider = nil
      }
    }
  }
}

private final class OAuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
  @MainActor
  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
  }
}
