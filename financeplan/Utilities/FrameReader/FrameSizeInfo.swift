#if DEBUG
  import SwiftUI

  struct FrameSizeInfo: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
      content.overlay {
        ZStack {
          Rectangle().stroke(color)
          GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            Text(String(format: "%.1f, %.1f, %.1fx%.1f", frame.minX, frame.minY, frame.width, frame.height))
              .font(.system(.footnote))
              .foregroundStyle(color.contrastingColor)
              .background(color)
              .fixedSize()
          }
        }
      }
    }
  }
#endif
