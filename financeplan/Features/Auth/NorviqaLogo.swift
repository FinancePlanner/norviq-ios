import SwiftUI

// Precision raster crops (docs/precision-identity.md). No glow: the artwork
// carries its own, and the brand rules out decorative shadows. The asset
// catalog images are 313x367 (symbol) and 805x367 (lockup); callers stay well
// under a third of that at 3x, so nothing upscales.

struct NorviqLogo: View {
  var size: CGFloat = 64

  var body: some View {
    Image("NorviqIcon")
      .resizable()
      .scaledToFit()
      .frame(width: size, height: size)
      .accessibilityLabel("Norviq")
  }
}

struct NorviqFullLogo: View {
  var width: CGFloat = 220

  /// The lockup's own aspect ratio (805x367), so the frame fits the art.
  private var height: CGFloat {
    width * 367 / 805
  }

  var body: some View {
    Image("NorviqFullLogo")
      .resizable()
      .scaledToFit()
      .frame(width: width, height: height)
      .accessibilityLabel("Norviq")
  }
}
