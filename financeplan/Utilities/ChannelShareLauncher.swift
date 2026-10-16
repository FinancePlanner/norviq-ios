import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Hands share text to a channel outside the app. Channels with a web intent
/// (X, Reddit, WhatsApp) open a prefilled URL and fall back to the system share
/// sheet; Discord has no intent URL, so its text is copied and the app opened.
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

  /// Copies `text`, then opens the Discord app, or Discord on the web when the
  /// app is not installed.
  func copyForDiscordAndOpen(_ text: String) {
    copyToPasteboard(text)
    showToast(.success(String(localized: "Opening Discord. Please paste your text there.")))

    guard let discordAppURL = URL(string: "discord://") else { return }
    openURL(discordAppURL) { accepted in
      guard !accepted else { return }
      if let webURL = URL(string: "https://discord.com/channels/@me") {
        openURL(webURL)
      }
    }
  }

  func copyToPasteboard(_ text: String) {
    #if canImport(UIKit)
    UIPasteboard.general.string = text
    #endif
  }
}
