import SwiftUI

#if DEBUG
  extension Color {
    var contrastingColor: Color {
      // Simple approach: default to white for unknown colors
      // This is debug-only code used for frame reader overlays
      return .white
    }
  }
#endif
