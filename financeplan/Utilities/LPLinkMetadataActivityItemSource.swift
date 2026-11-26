import LinkPresentation
import UIKit

/// Wraps an activity item so the iOS share sheet shows a rich preview
/// (title, optional icon, and image preview) in apps that read
/// `LPLinkMetadata` such as iMessage, Mail, and AirDrop.
///
/// Nonisolated: the share sheet asks for a file URL's item on a background
/// queue, and a main-actor witness traps there. Every property is a `let`.
nonisolated final class LPLinkMetadataActivityItemSource: NSObject, UIActivityItemSource {
  let title: String
  let item: Any
  let icon: UIImage?
  /// Shown as the preview when `item` is a file URL.
  let previewImage: UIImage?

  init(title: String, item: Any, icon: UIImage? = nil, previewImage: UIImage? = nil) {
    self.title = title
    self.item = item
    self.icon = icon
    self.previewImage = previewImage
  }

  func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
    item
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    itemForActivityType activityType: UIActivity.ActivityType?
  ) -> Any? {
    item
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    subjectForActivityType activityType: UIActivity.ActivityType?
  ) -> String {
    title
  }

  func activityViewControllerLinkMetadata(
    _ activityViewController: UIActivityViewController
  ) -> LPLinkMetadata? {
    let metadata = LPLinkMetadata()
    metadata.title = title
    if let icon {
      metadata.iconProvider = NSItemProvider(object: icon)
    }
    if let image = item as? UIImage {
      metadata.imageProvider = NSItemProvider(object: image)
    } else if let url = item as? URL, url.isFileURL {
      // A file's own URL is a local path, useless as a link preview.
      if let previewImage {
        metadata.imageProvider = NSItemProvider(object: previewImage)
      }
    } else if let url = item as? URL {
      metadata.originalURL = url
      metadata.url = url
    }
    return metadata
  }
}
