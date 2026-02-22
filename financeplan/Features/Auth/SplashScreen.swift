import SwiftUI

struct SplashScreen: View {
  @State private var pulse = false
  @State private var spin = false
  @State private var showText = false

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.06, green: 0.16, blue: 0.34),
          Color(red: 0.04, green: 0.09, blue: 0.20),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      Circle()
        .fill(Color.white.opacity(0.1))
        .frame(width: pulse ? 230 : 170, height: pulse ? 230 : 170)
        .blur(radius: 16)

      VStack(spacing: 18) {
        ZStack {
          Circle()
            .stroke(Color.white.opacity(0.35), lineWidth: 2)
            .frame(width: 96, height: 96)
            .rotationEffect(.degrees(spin ? 360 : 0))

          Circle()
            .fill(Color.white.opacity(0.9))
            .frame(width: 72, height: 72)
            .overlay(
              Text("FP")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.04, green: 0.09, blue: 0.20))
            )
        }

        VStack(spacing: 6) {
          Text("FinPlanner")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 8)

          Text("Loading your workspace")
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.8))
            .opacity(showText ? 1 : 0)
        }
      }
      .padding(.horizontal, 24)
    }
    .onAppear {
      withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
        pulse = true
      }
      withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
        spin = true
      }
      withAnimation(.easeOut(duration: 0.45).delay(0.2)) {
        showText = true
      }
    }
  }
}
