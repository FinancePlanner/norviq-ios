import SwiftUI

struct SplashScreen: View {
  @State private var isAnimating = false

  var body: some View {
    ZStack {
      Color.black
        .ignoresSafeArea()

      Image("OwlMascotSplash")
        .resizable()
        .scaledToFill()
        .ignoresSafeArea()
        .scaleEffect(isAnimating ? 1.02 : 1.0)
        .opacity(isAnimating ? 1.0 : 0.9)
    }
    .onAppear {
      withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
        isAnimating = true
      }
    }
  }
}
