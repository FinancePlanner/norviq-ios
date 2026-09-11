import Foundation
import UIKit

/// Shrinks images before they are uploaded to a vision model.
///
/// Two reasons, both practical: a raw iPhone screenshot or photo is several
/// megabytes and trips the backend's 8 MB per-image cap, and vision models
/// tile images above roughly 1568px without reading anything more from them —
/// so the extra pixels cost tokens and latency and buy no accuracy.
enum UploadImagePreparer {
  /// Longest-edge ceiling. Matches the tile size above which the major vision
  /// models stop gaining detail.
  static let maxDimension: CGFloat = 1568

  /// Backend rejects anything larger. Kept here so the app fails fast with a
  /// clear message instead of round-tripping a doomed upload.
  static let maxBytes = 8 * 1024 * 1024

  /// Re-encodes image data as a JPEG no larger than `maxDimension` on its long
  /// edge. Returns nil when the bytes are not a decodable image.
  ///
  /// Quality steps down only if the first encode is still over the cap, so the
  /// common case pays for exactly one encode.
  static func prepare(_ data: Data, quality: CGFloat = 0.7) -> ScreenshotUploadImage? {
    guard let image = UIImage(data: data) else { return nil }

    let resized = downscaled(image)
    for attempt in [quality, 0.5, 0.35] {
      guard let encoded = resized.jpegData(compressionQuality: attempt) else { continue }
      if encoded.count <= maxBytes {
        return ScreenshotUploadImage(data: encoded, contentType: "image/jpeg")
      }
    }
    return nil
  }

  /// Scales the long edge down to `maxDimension`, preserving aspect ratio.
  /// Images already within the ceiling are returned untouched — re-encoding a
  /// small screenshot only softens the text the model has to read.
  static func downscaled(_ image: UIImage) -> UIImage {
    let longEdge = max(image.size.width, image.size.height)
    guard longEdge > maxDimension, longEdge > 0 else { return image }

    let scale = maxDimension / longEdge
    let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)

    let format = UIGraphicsImageRendererFormat.default()
    // Render at 1x: the target size is already in pixels, and letting the
    // renderer apply the screen scale would undo the downscale entirely.
    format.scale = 1
    return UIGraphicsImageRenderer(size: target, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: target))
    }
  }
}
