import OSLog
import SafariServices
import SwiftUI

private let safariLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
  category: "SafariView"
)

struct SafariView: UIViewControllerRepresentable {
  let url: URL

  func makeUIViewController(context: Context) -> UIViewController {
    safariLogger.info(
      "Preparing Safari presentation for URL: \(url.absoluteString, privacy: .public)")

    guard isWebURL(url) else {
      let controller = UIAlertController(
        title: "Invalid Link", message: "This isn’t a valid web URL: \n\n\(url.absoluteString)",
        preferredStyle: .alert)
      controller.addAction(UIAlertAction(title: "OK", style: .default))
      return controller
    }

    let config = SFSafariViewController.Configuration()
    config.entersReaderIfAvailable = false
    config.barCollapsingEnabled = true

    let safariVC = SFSafariViewController(url: url, configuration: config)
    safariVC.delegate = context.coordinator

    safariLogger.debug("SFSafariViewController created successfully")
    return safariVC
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    // No updates needed
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  class Coordinator: NSObject, SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
      safariLogger.info("Safari view controller finished browsing")
    }

    func safariViewController(
      _ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool
    ) {
      safariLogger.info(
        "Safari initial load completed: success=\(didLoadSuccessfully, privacy: .public)")
      if !didLoadSuccessfully {
        safariLogger.notice("Safari failed to load the page")
      }
    }

    func safariViewController(
      _ controller: SFSafariViewController, initialLoadDidRedirectTo URL: URL
    ) {
      safariLogger.info("Safari redirected to: \(URL.absoluteString, privacy: .public)")
    }
  }

  private func isWebURL(_ url: URL) -> Bool {
    guard let scheme = url.scheme?.lowercased() else { return false }
    return (scheme == "http" || scheme == "https") && url.host != nil
  }
}
