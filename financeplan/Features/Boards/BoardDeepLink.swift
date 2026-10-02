import Foundation

/// `financeplan://boards/{slug}/posts/{postId}`, the link board pushes carry.
enum BoardDeepLink {
  static func postID(from url: URL) -> UUID? {
    guard url.scheme == "financeplan", url.host() == "boards" else { return nil }
    let parts = url.pathComponents.filter { $0 != "/" }
    guard parts.count == 3, parts[1] == "posts" else { return nil }
    return UUID(uuidString: parts[2])
  }
}

extension Notification.Name {
  /// Posted by `ContentView` to open a board post. `userInfo["postId"]` is its UUID string.
  static let openBoardPostFromPushNotification = Notification.Name("openBoardPostFromPushNotification")
}
