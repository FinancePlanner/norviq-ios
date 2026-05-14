import SwiftUI

enum ContentWidth {
  static let form: CGFloat = 520
  static let marketing: CGFloat = 560
  static let dense: CGFloat = 720
}

struct MaxContentWidthModifier: ViewModifier {
  let maxWidth: CGFloat?

  func body(content: Content) -> some View {
    if let maxWidth {
      content
        .frame(maxWidth: maxWidth)
        .frame(maxWidth: .infinity)
    } else {
      content
    }
  }
}

private struct RegularSizeClassMaxWidthModifier: ViewModifier {
  let maxWidth: CGFloat
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  func body(content: Content) -> some View {
    if horizontalSizeClass == .regular {
      content
        .frame(maxWidth: maxWidth)
        .frame(maxWidth: .infinity)
    } else {
      content
    }
  }
}

extension View {
  func maxContentWidth(_ width: CGFloat?) -> some View {
    modifier(MaxContentWidthModifier(maxWidth: width))
  }

  func maxContentWidth(regularSizeClass width: CGFloat) -> some View {
    modifier(RegularSizeClassMaxWidthModifier(maxWidth: width))
  }
}
