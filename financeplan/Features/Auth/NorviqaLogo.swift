import SwiftUI

struct NorviqaLogo: View {
  var size: CGFloat = 64

  var body: some View {
    Image("NorviqaLogoLight")
      .resizable()
      .scaledToFit()
      .frame(width: size, height: size)
      .shadow(
        color: AppTheme.Colors.tint(for: .dark).opacity(0.3),
        radius: 15,
        x: 0,
        y: 8
      )
  }
}
