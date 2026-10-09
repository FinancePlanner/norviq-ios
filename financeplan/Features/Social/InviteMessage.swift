import Foundation

/// The one invite text every channel sends, so the share sheet, Messages and
/// Messenger all say the same thing.
nonisolated enum InviteMessage {
  static func text(for url: URL) -> String {
    String(
      localized: "Let's track our goals together on Norviq: \(url.absoluteString)",
      comment: "Invite text sent by share sheet, Messages and Messenger. The placeholder is the invite link; keep it last."
    )
  }
}
