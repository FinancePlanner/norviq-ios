import SwiftUI

public struct MeshGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animate = false

    public init() {}

    public var body: some View {
        ZStack {
            AppTheme.Colors.pageBackground(for: colorScheme)
                .ignoresSafeArea()

            GeometryReader { proxy in
                ZStack {
                    // Orb 1: Neon Tint
                    Circle()
                        .fill(AppTheme.Colors.tint(for: colorScheme).opacity(0.25))
                        .frame(width: proxy.size.width * 0.9)
                        .blur(radius: 90)
                        .offset(
                            x: animate ? -proxy.size.width * 0.2 : proxy.size.width * 0.2,
                            y: animate ? -proxy.size.height * 0.1 : proxy.size.height * 0.3)

                    // Orb 2: Purple/Blue Accent
                    Circle()
                        .fill(Color(red: 0.60, green: 0.20, blue: 1.00).opacity(0.15))  // Purple neon
                        .frame(width: proxy.size.width * 0.8)
                        .blur(radius: 90)
                        .offset(
                            x: animate ? proxy.size.width * 0.4 : -proxy.size.width * 0.2,
                            y: animate ? proxy.size.height * 0.5 : -proxy.size.height * 0.1)

                    // Orb 3: Highlight
                    Circle()
                        .fill(AppTheme.Colors.tintSoft(for: colorScheme).opacity(0.3))
                        .frame(width: proxy.size.width * 0.6)
                        .blur(radius: 70)
                        .offset(
                            x: animate ? proxy.size.width * 0.1 : proxy.size.width * 0.6,
                            y: animate ? proxy.size.height * 0.8 : proxy.size.height * 0.4)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
        .ignoresSafeArea()
    }
}
