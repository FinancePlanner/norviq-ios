import Foundation
import ImageIO
import UIKit

/// Shrinks images before they are uploaded to a vision model.
///
/// Two reasons, both practical: a raw iPhone screenshot or photo is several
/// megabytes and trips the backend's 8 MB per-image cap, and vision models
/// tile images above roughly 1568px without reading anything more from them —
/// so the extra pixels cost tokens and latency and buy no accuracy.
nonisolated enum UploadImagePreparer {
  /// Longest-edge ceiling. Matches the tile size above which the major vision
  /// models stop gaining detail.
  static let maxDimension: CGFloat = 1568

  /// Backend rejects anything larger on the import routes. Kept here so the app fails fast with a
  /// clear message instead of round-tripping a doomed upload.
  static let maxBytes = 8 * 1024 * 1024

  /// Re-encodes image data as a JPEG no larger than `maxDimension` on its long
  /// edge. Returns nil when the bytes are not a decodable image.
  ///
  /// Quality steps down only if the first encode is still over the cap, so the
  /// common case pays for exactly one encode. `maxBytes` lets a call with a
  /// tighter backend limit say so.
  static func prepare(
    _ data: Data,
    quality: CGFloat = 0.7,
    maxBytes: Int = UploadImagePreparer.maxBytes
  ) -> ScreenshotUploadImage? {
    guard let resized = decodedUpright(data) else { return nil }

    for attempt in [quality, 0.5, 0.35] {
      guard let encoded = resized.jpegData(compressionQuality: attempt) else { continue }
      if encoded.count <= maxBytes {
        return ScreenshotUploadImage(data: encoded, contentType: "image/jpeg")
      }
    }
    return nil
  }

  /// Decodes at most `maxDimension` on the long edge, with the EXIF orientation
  /// applied to the pixels. ImageIO decodes straight to that size, so a 48 MP
  /// photo never becomes a full-size bitmap (about 190 MB), and an image already
  /// within the ceiling keeps its size. Baking the orientation in matters
  /// because the JPEG written afterwards would otherwise keep it only as a tag.
  static func decodedUpright(_ data: Data) -> UIImage? {
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    // A source is made for any bytes; one with no image in it is not an image.
    guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
          CGImageSourceGetCount(source) > 0
    else { return nil }
    let options = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension),
    ] as CFDictionary
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
    return UIImage(cgImage: image)
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
