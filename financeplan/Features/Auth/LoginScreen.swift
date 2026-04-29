import Factory
import SwiftUI
import StockPlanShared

struct LoginScreen: View {
  @InjectedObject(\Container.windowSize) private var windowSize
  @InjectedObservable(\Container.appEnvironment) private var environment
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var viewModel: LoginViewModel

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
  init(onAuthenticated: @escaping () -> Void = {}, startWithSignup: Bool = false) {
    _viewModel = StateObject(
      wrappedValue: {
        let vm = LoginViewModel(
          authService: Container.shared.authService(),
          sessionStore: Container.shared.authSessionStore(),
          onAuthenticated: onAuthenticated
        )
        if startWithSignup {
          vm.showSignup()
        }
        return vm
      }()
    )
  }

  var body: some View {
    ZStack {
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
    .background {
      MeshGradientBackground()
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
  }

  @ViewBuilder
  private var authContent: some View {
    if viewModel.isSignup {
      SignUpView(viewModel: viewModel)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    } else {
      SignInView(viewModel: viewModel)
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
