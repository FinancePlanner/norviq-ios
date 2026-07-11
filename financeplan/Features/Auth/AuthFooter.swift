import SwiftUI
import Factory

struct AuthFooter: View {
  @State private var isEnvironmentPresented = false
  @Environment(\.colorScheme) private var colorScheme
  @InjectedObservable(\Container.appEnvironment) private var environment

  private var showEnvironmentButton: Bool {
    #if DEBUG
    return true
    #else
    return environment.current != AppEnvironments.production
    #endif
  }

  var body: some View {
    VStack(spacing: 16) {
      HStack(spacing: 24) {
        Button("Privacy Policy") {}
          .font(.caption)
          .foregroundStyle(.secondary)

        if showEnvironmentButton {
          Button("Environment") {
            isEnvironmentPresented = true
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }

      Text("© 2024 The Editorial Financial Experience. All rights reserved.")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(.bottom, 40)
    .confirmationDialog(
      "Switch from \(environment.current.title) to",
      isPresented: $isEnvironmentPresented,
      titleVisibility: .visible
    ) {
      ForEach(environment.allowedEnvironmentsWhen(isLoggedIn: false), id: \.title) { env in
        Button(action: {
          environment.change(to: env)
        }) {
          Text(env.title)
        }
        .disabled(env == environment.current)
      }
    }
  }
}
