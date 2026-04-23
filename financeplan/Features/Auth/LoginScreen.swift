import Factory
import SwiftUI
import StockPlanShared

struct LoginScreen: View {
  @InjectedObject(\Container.windowSize) private var windowSize
  @InjectedObservable(\Container.appEnvironment) private var environment
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var viewModel: LoginViewModel

  @State private var isEnvironmentPresented = false

  private var isMFAPresented: Binding<Bool> {
    Binding(
      get: { viewModel.pendingMFAChallenge != nil },
      set: { isPresented in
        if !isPresented {
          viewModel.dismissMFAFlow()
        }
      }
    )
  }

  @MainActor
  init(onAuthenticated: @escaping () -> Void = {}) {
    _viewModel = StateObject(
      wrappedValue: LoginViewModel(
        authService: Container.shared.authService(),
        sessionStore: Container.shared.authSessionStore(),
        onAuthenticated: onAuthenticated
      )
    )
  }

  var body: some View {
    ZStack {
      MeshGradientBackground()

      authContent

      if let error = viewModel.error {
        VStack {
          FormErrorBanner(message: error)
            .padding()
          Spacer()
        }
        .zIndex(100)
        .transition(.move(edge: .top).combined(with: .opacity))
      }

      if let info = viewModel.infoMessage {
        VStack {
          ToastBanner(message: info, style: .success)
            .padding()
          Spacer()
        }
        .zIndex(100)
        .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .animation(.easeInOut(duration: 0.3), value: viewModel.isSignup)
    .sheet(isPresented: $viewModel.isForgotPasswordPresented) {
      forgotPasswordSheet
    }
    .sheet(isPresented: isMFAPresented) {
      mfaSheet
    }
    .task(id: viewModel.infoMessage) {
      await autoDismissInfoMessage()
    }
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

  @ViewBuilder
  private var authContent: some View {
    if viewModel.isSignup {
      SignUpView(viewModel: viewModel, isEnvironmentPresented: $isEnvironmentPresented)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    } else {
      SignInView(viewModel: viewModel, isEnvironmentPresented: $isEnvironmentPresented)
        .transition(.opacity.combined(with: .move(edge: .leading)))
    }
  }

  private var forgotPasswordSheet: some View {
    VaultForgotPasswordView(viewModel: viewModel)
      .presentationDetents([.large])
      .presentationDragIndicator(.visible)
  }

  private var mfaSheet: some View {
    VaultMFAVerificationView(viewModel: viewModel)
      .presentationDetents([.medium])
      .presentationDragIndicator(.visible)
  }

  private func autoDismissInfoMessage() async {
    guard let currentMessage = viewModel.infoMessage else { return }
    try? await Task.sleep(for: .seconds(3))
    guard viewModel.infoMessage == currentMessage else { return }
    withAnimation(.easeInOut(duration: 0.2)) {
      viewModel.infoMessage = nil
    }
  }
}
