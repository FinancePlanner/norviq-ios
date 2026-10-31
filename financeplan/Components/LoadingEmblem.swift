import SwiftUI

/// The Precision loading mark: the logo's four-point star, breathing slowly in
/// opacity only (docs/precision-identity.md, Motion). Under Reduce Motion it is
/// a static star. Decorative: pair it with a text status for VoiceOver.
struct LoadingEmblem: View {
  var size: CGFloat = 28

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var dimmed = false

  var body: some View {
    FourPointStar()
      .fill(AppTheme.Colors.tint)
      .frame(width: size, height: size)
      .opacity(dimmed ? 0.35 : 1)
      .accessibilityHidden(true)
      .onAppear {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
          dimmed = true
        }
      }
  }
}

/// A four-point star with concave sides, matching the star inside the logo ring.
struct FourPointStar: Shape {
  /// Waist of the star as a fraction of its radius: smaller is sharper.
  var waist: CGFloat = 0.16

  func path(in rect: CGRect) -> Path {
    let c = CGPoint(x: rect.midX, y: rect.midY)
    let r = min(rect.width, rect.height) / 2
    let w = r * waist
    var path = Path()
    path.move(to: CGPoint(x: c.x, y: c.y - r))
    path.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + w, y: c.y - w))
    path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + w, y: c.y + w))
    path.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - w, y: c.y + w))
    path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - w, y: c.y - w))
    path.closeSubpath()
    return path
  }
}

#Preview {
  LoadingEmblem(size: 48)
    .padding()
}
