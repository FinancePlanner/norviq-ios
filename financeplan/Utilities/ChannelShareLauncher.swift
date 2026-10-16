import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Hands share text to a channel outside the app. Channels with a web intent
/// (X, Reddit, WhatsApp) open a prefilled URL and fall back to the system share
/// sheet. Discord goes through the share sheet, whose Discord extension asks
/// for the server and channel.
///
/// Shared by the stock share buttons and the market brief share menu, which
/// each own the share sheet and toast it drives.
struct ChannelShareLauncher {
  let openURL: OpenURLAction
  /// Shows the system share sheet with these items.
  let presentShareSheet: ([Any]) -> Void
  let showToast: (ToastData) -> Void

  /// Opens `url`, or the share sheet with `fallbackItems` when it is missing or
  /// nothing on the device accepts it.
  func open(_ url: URL?, fallbackItems: [Any]) {
    guard let url else {
      showToast(.error(String(localized: "Could not build share link. Opened iOS share sheet instead.")))
      presentShareSheet(fallbackItems)
      return
    }

    openURL(url) { accepted in
      if !accepted {
        showToast(.info(String(localized: "Share target unavailable. Opened iOS share sheet.")))
        presentShareSheet(fallbackItems)
      }
    }
  }

  /// Discord has no URL that opens its server and channel picker, but its
  /// share extension does, so the text goes to the system share sheet. It is
  /// also copied, for when the Discord extension isn't enabled on the device.
  func shareToDiscord(_ text: String) {
    copyToPasteboard(text)
    showToast(.info(String(localized: "Choose Discord, then pick the channel. The text is also copied.")))
    presentShareSheet([text])
  }

  func copyToPasteboard(_ text: String) {
    #if canImport(UIKit)
    UIPasteboard.general.string = text
    #endif
  }
}
