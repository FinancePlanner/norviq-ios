import MessageUI
import SwiftUI

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
