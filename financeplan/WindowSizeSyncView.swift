import Factory
import SwiftUI

struct WindowSizeSyncView: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @InjectedObject(\Container.windowSize) private var windowSize

  var body: some View {
    Color.clear
      .readSize(into: $windowSize.size)
      .onAppear { windowSize.updateSizeClass(horizontalSizeClass) }
      .onChange(of: horizontalSizeClass) { _, new in
        windowSize.updateSizeClass(new)
      }
  }
}
