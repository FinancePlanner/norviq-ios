import SwiftUI

#if DEBUG
  extension Color {
    var contrastingColor: Color {
      // Use SwiftUI's resolved color API for extracting components
      // Fallback to luminance-based calculation
      let mirror = Mirror(reflecting: self)
      // Simple approach: default to white for unknown colors
      // This is debug-only code used for frame reader overlays
      return .white
    }
  }
#endif
