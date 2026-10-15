import SwiftUI
import UIKit

/// The one place the AI consent sheet is presented from.
///
/// Presented with UIKit on the top-most view controller rather than as a
/// SwiftUI `.sheet` on each AI surface: AI surfaces are often sheets
/// themselves, and a surface under another sheet (a gated tab under the
/// assistant) cannot present. With one app-wide presenter there is nothing
/// to claim, so nothing can be left holding the prompt.
///
/// `presented` is weak: however the sheet goes away — Allow, Not now, a
/// swipe, or the sheet under it being dismissed — the controller is released
/// and the next request presents again.
@MainActor
final class AIConsentPresenter {
  static let shared = AIConsentPresenter()

  private weak var presented: UIViewController?
  private var pendingRetry = false

  var isPresenting: Bool { presented != nil }

  func present() {
    guard presented == nil else { return }
    guard let top = Self.topViewController(), !top.isBeingDismissed, !top.isBeingPresented else {
      // Mid-transition (a sheet opening or closing): try once more shortly.
      scheduleRetry()
      return
    }
    let host = UIHostingController(rootView: AIConsentSheet(onClose: { [weak self] in self?.dismiss() }))
    host.modalPresentationStyle = .pageSheet
    if let sheet = host.sheetPresentationController {
      sheet.detents = [.large()]
      sheet.prefersGrabberVisible = true
    }
    presented = host
    top.present(host, animated: true)
  }

  func dismiss() {
    presented?.dismiss(animated: true)
    presented = nil
  }

  private func scheduleRetry() {
    guard !pendingRetry else { return }
    pendingRetry = true
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(600))
      guard let self else { return }
      self.pendingRetry = false
      guard self.presented == nil,
            let top = Self.topViewController(),
            !top.isBeingDismissed, !top.isBeingPresented
      else { return }
      self.present()
    }
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes
      .filter { $0.activationState == .foregroundActive }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
      ?? scenes.flatMap(\.windows).first(where: \.isKeyWindow)
    var top = window?.rootViewController
    while let next = top?.presentedViewController, !next.isBeingDismissed {
      top = next
    }
    return top
  }
}
