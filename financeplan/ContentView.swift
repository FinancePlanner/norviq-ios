import Factory
import SwiftUI

public struct ContentView: View {
  @State private var launchCompleted = false
  @State private var launchStarted = false
  @State private var isAuthenticated: Bool
  private let sessionStore: AuthSessionStoring

  public init() {
    let store = Container.shared.authSessionStore()
    sessionStore = store
    _isAuthenticated = State(initialValue: !store.authToken.isEmpty)
  }

  public var body: some View {
    ZStack {
      WindowSizeSyncView()

      if launchCompleted {
        if isAuthenticated {
          AuthenticatedHomeView(
            onLogout: {
              sessionStore.authToken = ""
              sessionStore.refreshToken = ""
              isAuthenticated = false
            }
          )
        } else {
          LoginScreen(onAuthenticated: {
            isAuthenticated = true
          })
        }
      } else {
        SplashScreen()
          .transition(.opacity)
      }
    }
    .task {
      guard !launchStarted else {
        return
      }

      launchStarted = true
      try? await Task.sleep(nanoseconds: 2_000_000_000)

      withAnimation(.easeInOut(duration: 0.4)) {
        launchCompleted = true
      }
    }
  }
}

private struct AuthenticatedHomeView: View {
  let onLogout: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 44))
        .foregroundStyle(.green)

      Text("Signed in")
        .font(.title2)
        .fontWeight(.semibold)

      Text("Authentication completed successfully.")
        .font(.footnote)
        .foregroundStyle(.secondary)

      Button("Log out") {
        onLogout()
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemBackground).ignoresSafeArea())
  }
}
