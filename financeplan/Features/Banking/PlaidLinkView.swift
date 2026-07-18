import LinkKit
import SwiftUI

/// Presents Plaid Link for a given link token and reports the resulting public
/// token (and institution) back to the caller. The image/credentials never
/// touch Norviq — Plaid Link handles the bank handshake and returns only a
/// short-lived public token to exchange server-side.
struct PlaidLinkView: UIViewControllerRepresentable {
  let linkToken: String
  let onSuccess: (_ publicToken: String, _ institutionId: String?, _ institutionName: String?) -> Void
  let onExit: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(linkToken: linkToken, onSuccess: onSuccess, onExit: onExit)
  }

  func makeUIViewController(context: Context) -> UIViewController {
    let controller = UIViewController()
    context.coordinator.present(from: controller)
    return controller
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

  final class Coordinator {
    private let linkToken: String
    private let onSuccess: (_ publicToken: String, _ institutionId: String?, _ institutionName: String?) -> Void
    private let onExit: () -> Void
    private var handler: Handler?
    private var hasPresented = false

    init(
      linkToken: String,
      onSuccess: @escaping (_ publicToken: String, _ institutionId: String?, _ institutionName: String?) -> Void,
      onExit: @escaping () -> Void
    ) {
      self.linkToken = linkToken
      self.onSuccess = onSuccess
      self.onExit = onExit
    }

    func present(from controller: UIViewController) {
      guard !hasPresented else { return }
      hasPresented = true

      var configuration = LinkTokenConfiguration(token: linkToken) { [weak self] success in
        let institution = success.metadata.institution
        self?.onSuccess(success.publicToken, institution.id, institution.name)
      }
      configuration.onExit = { [weak self] _ in
        self?.onExit()
      }

      switch Plaid.create(configuration) {
      case let .success(handler):
        self.handler = handler
        // Present once the representable's controller is in the hierarchy.
        DispatchQueue.main.async {
          handler.open(presentUsing: .viewController(controller))
        }
      case let .failure(error):
        assertionFailure("Plaid Link creation failed: \(error)")
        onExit()
      }
    }
  }
}
