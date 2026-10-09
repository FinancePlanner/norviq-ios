import Foundation

/// Messenger without the Facebook SDK: there is no Meta app ID, so the SDK's
/// message dialog is unavailable. The app scheme is undocumented. Without
/// Messenger installed the fallback is Facebook's web sharer, which posts to
/// the Facebook feed rather than sending a message, so the button that opens
/// it must say "Share on Facebook".
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
