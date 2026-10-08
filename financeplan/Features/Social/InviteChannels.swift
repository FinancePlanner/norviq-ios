import MessageUI
import SwiftUI

/// The one invite text every channel sends, so the share sheet, Messages and
/// Messenger all say the same thing.
nonisolated enum InviteMessage {
  static func text(for url: URL) -> String {
    "Let's track our goals together on Norviq: \(url.absoluteString)"
  }
}

/// Messenger without the Facebook SDK: there is no Meta app ID, so the SDK's
/// message dialog is unavailable. The app scheme is undocumented, so the web
/// sharer is the fallback whenever Messenger isn't installed.
nonisolated enum MessengerShare {
  static let appScheme = URL(string: "fb-messenger://")!

  static func appURL(for invite: URL) -> URL? {
    URL(string: "fb-messenger://share?link=\(encoded(invite))")
  }

  static func webFallbackURL(for invite: URL) -> URL? {
    URL(string: "https://www.facebook.com/sharer/sharer.php?u=\(encoded(invite))")
  }

  /// Unreserved characters only, so `:` `/` `?` `&` in the link can't be read
  /// as part of the outer URL.
  private static func encoded(_ url: URL) -> String {
    let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
    return url.absoluteString.addingPercentEncoding(withAllowedCharacters: unreserved) ?? url.absoluteString
  }
}

/// Messages compose sheet with the invite as its body and an empty To: field,
/// where the user picks a contact or types a phone number. Callers check
/// `canSendText` before offering it; simulators and some iPads can't text.
struct MessageComposeView: UIViewControllerRepresentable {
  static var canSendText: Bool { MFMessageComposeViewController.canSendText() }

  let body: String
  let onFinish: () -> Void

  func makeUIViewController(context: Context) -> MFMessageComposeViewController {
    let controller = MFMessageComposeViewController()
    controller.body = body
    controller.messageComposeDelegate = context.coordinator
    return controller
  }

  func updateUIViewController(_: MFMessageComposeViewController, context _: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

  final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

    func messageComposeViewController(
      _: MFMessageComposeViewController,
      didFinishWith _: MessageComposeResult
    ) {
      onFinish()
    }
  }
}
