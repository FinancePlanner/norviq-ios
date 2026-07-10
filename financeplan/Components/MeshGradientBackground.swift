import SwiftUI

public struct MeshGradientBackground: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var animate = false
  private let animatesOnAppear: Bool

  public init(animatesOnAppear: Bool = false) {
    self.animatesOnAppear = animatesOnAppear
  }

  public var body: some View {
    ZStack {
      AppTheme.Colors.pageBackground(for: colorScheme)
        .ignoresSafeArea()

      GeometryReader { proxy in
        ZStack {
          RoundedRectangle(cornerRadius: 36, style: .continuous)
            .fill(
              LinearGradient(
                colors: [
                  AppTheme.Colors.tint(for: colorScheme).opacity(colorScheme == .dark ? 0.16 : 0.10),
                  AppTheme.Colors.secondaryTint(for: colorScheme).opacity(colorScheme == .dark ? 0.10 : 0.07),
                  .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: proxy.size.width * 0.86, height: proxy.size.height * 0.24)
            .blur(radius: 50)
            .offset(
              x: animate ? -proxy.size.width * 0.05 : proxy.size.width * 0.04,
              y: -proxy.size.height * 0.30
            )

          Circle()
            .fill(AppTheme.Colors.tintSoft(for: colorScheme).opacity(colorScheme == .dark ? 0.9 : 0.75))
            .frame(width: proxy.size.width * 0.72)
            .blur(radius: 85)
            .offset(
              x: animate ? proxy.size.width * 0.26 : proxy.size.width * 0.18,
              y: proxy.size.height * 0.58
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .onAppear {
      guard animatesOnAppear, !reduceMotion else { return }
      withAnimation(.easeOut(duration: 0.6)) { animate = true }
    }
    .ignoresSafeArea()
  }
}
