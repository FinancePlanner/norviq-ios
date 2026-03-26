import SwiftUI

public struct MeshGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    public init() {}

    public var body: some View {
        ZStack {
            AppTheme.Colors.pageBackground(for: colorScheme)
                .ignoresSafeArea()

            GeometryReader { proxy in
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.tint(for: colorScheme).opacity(colorScheme == .dark ? 0.18 : 0.14))
                        .frame(width: proxy.size.width * 0.9)
                        .blur(radius: 110)
                        .offset(
                            x: animate ? -proxy.size.width * 0.16 : proxy.size.width * 0.18,
                            y: animate ? -proxy.size.height * 0.08 : proxy.size.height * 0.24)

                    Circle()
                        .fill(AppTheme.Colors.secondaryTint(for: colorScheme).opacity(colorScheme == .dark ? 0.12 : 0.10))
                        .frame(width: proxy.size.width * 0.8)
                        .blur(radius: 100)
                        .offset(
                            x: animate ? proxy.size.width * 0.32 : -proxy.size.width * 0.18,
                            y: animate ? proxy.size.height * 0.42 : -proxy.size.height * 0.06)

                    Circle()
                        .fill(AppTheme.Colors.tintSoft(for: colorScheme).opacity(colorScheme == .dark ? 0.22 : 0.28))
                        .frame(width: proxy.size.width * 0.6)
                        .blur(radius: 80)
                        .offset(
                            x: animate ? proxy.size.width * 0.08 : proxy.size.width * 0.52,
                            y: animate ? proxy.size.height * 0.72 : proxy.size.height * 0.34)
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
        .ignoresSafeArea()
    }
}
