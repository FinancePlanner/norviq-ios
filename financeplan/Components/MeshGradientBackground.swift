import SwiftUI

/// Flat page background. Previously an animated blurred-gradient mesh with a
/// Vigil-only circuit grid overlay — both retired in favor of a plain surface
/// consistent with the rest of the app's flat card/panel treatment.
public struct MeshGradientBackground: View {
  @Environment(\.colorScheme) private var colorScheme

  public init(animatesOnAppear: Bool = false) {}

  public var body: some View {
    AppTheme.Colors.pageBackground(for: colorScheme)
      .ignoresSafeArea()
  }
}
