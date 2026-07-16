import SwiftUI

struct NorviqLogo: View {
  var size: CGFloat = 64

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Image("CerberusHeadIcon")
      .resizable()
      .scaledToFit()
      .frame(width: size, height: size)
      .accessibilityLabel("Norviq")
      .shadow(
        color: AppTheme.Colors.tint(for: colorScheme).opacity(0.18),
        radius: 12,
        x: 0,
        y: 7
      )
  }
}

struct NorviqFullLogo: View {
  var width: CGFloat = 220

  @Environment(\.colorScheme) private var colorScheme

  private var height: CGFloat {
    width / 3
  }

  var body: some View {
    Image("NorviqFullLogo")
      .resizable()
      .scaledToFit()
      .frame(width: width, height: height)
      .accessibilityLabel("Norviq")
      .shadow(
        color: AppTheme.Colors.tint(for: colorScheme).opacity(0.14),
        radius: 12,
        x: 0,
        y: 7
      )
  }
}
