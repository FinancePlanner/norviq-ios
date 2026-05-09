import LinkPresentation
import UIKit

/// Wraps an activity item so the iOS share sheet shows a rich preview
/// (title, optional icon, and image preview) in apps that read
/// `LPLinkMetadata` such as iMessage, Mail, and AirDrop.
final class LPLinkMetadataActivityItemSource: NSObject, UIActivityItemSource {
  let title: String
  let item: Any
  let icon: UIImage?

  init(title: String, item: Any, icon: UIImage? = nil) {
    self.title = title
    self.item = item
    self.icon = icon
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
    } else if let url = item as? URL {
      metadata.originalURL = url
      metadata.url = url
    }
    return metadata
  }
}
