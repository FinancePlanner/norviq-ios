import CoreImage.CIFilterBuiltins
import UIKit

enum QRCodeGenerator {
  /// A crisp QR image for `string`, scaled with nearest-neighbour so the
  /// modules stay sharp at any size.
  static func image(for string: String, scale: CGFloat = 12) -> UIImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
          let cgImage = CIContext().createCGImage(output, from: output.extent)
    else { return nil }
    return UIImage(cgImage: cgImage)
  }
}
