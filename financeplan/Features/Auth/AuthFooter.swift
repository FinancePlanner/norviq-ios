import SwiftUI
import Factory

struct AuthFooter: View {
  @Binding var isEnvironmentPresented: Bool
  @Environment(\.colorScheme) private var colorScheme
  @InjectedObservable(\Container.appEnvironment) private var environment

  private var showEnvironmentButton: Bool {
    environment.current != AppEnvironments.production
  }

  var body: some View {
    VStack(spacing: 16) {
      HStack(spacing: 24) {
        Button("Privacy Policy") {}
          .font(.caption)
          .foregroundStyle(.secondary)

        Button("Terms of Service") {}
          .font(.caption)
          .foregroundStyle(.secondary)

        Button("Help Center") {}
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
        .foregroundStyle(.secondary.opacity(0.6))
    }
    .padding(.bottom, 40)
  }
}
