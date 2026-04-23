import SwiftUI

struct SocialAuthSection: View {
  @ObservedObject var viewModel: LoginViewModel
  let intentLabel: String

  var body: some View {
    VStack(spacing: 14) {
      HStack(spacing: 10) {
        Rectangle()
          .fill(.separator.opacity(0.5))
          .frame(height: 1)

        Text("OR")
          .font(.caption.weight(.bold))
          .tracking(1.2)
          .foregroundStyle(.secondary)

        Rectangle()
          .fill(.separator.opacity(0.5))
          .frame(height: 1)
      }

      VStack(spacing: 12) {
        ForEach(SocialAuthProvider.allCases) { provider in
          SocialAuthButton(provider: provider) {
            if let oauthProvider = provider.oauthProvider {
              Task { await viewModel.signInWithOAuth(oauthProvider) }
              return
            }

            withAnimation(.easeInOut(duration: 0.2)) {
              viewModel.error = nil
              viewModel.infoMessage = "\(provider.platformName) \(intentLabel) will be available soon."
            }
          }
        }
      }
    }
  }
}
