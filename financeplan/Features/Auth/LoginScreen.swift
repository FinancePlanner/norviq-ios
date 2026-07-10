import Factory
import SwiftUI
import StockPlanShared

struct LoginScreen: View {
  @InjectedObject(\Container.windowSize) private var windowSize
  @InjectedObservable(\Container.appEnvironment) private var environment
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @StateObject private var viewModel: LoginViewModel
  @State private var isShowingMFA = false

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
        .transition(AppTransition.move(edge: .top, reduceMotion: reduceMotion))
      }

      if let info = viewModel.infoMessage {
        VStack {
          ToastBanner(message: info, style: .success)
            .padding()
          Spacer()
        }
        .zIndex(100)
        .transition(AppTransition.move(edge: .top, reduceMotion: reduceMotion))
      }
    }
    .background {
      MeshGradientBackground()
    }
    .appAnimation(AppMotion.state, value: viewModel.isSignup)
    .appAnimation(AppMotion.structural, value: viewModel.error)
    .appAnimation(AppMotion.structural, value: viewModel.infoMessage)
    .sheet(isPresented: $viewModel.isForgotPasswordPresented) {
      forgotPasswordSheet
    }
    .sheet(isPresented: $isShowingMFA) {
      mfaSheet
    }
    .onChange(of: viewModel.pendingMFAChallenge) { _, newValue in
      isShowingMFA = (newValue != nil)
    }
    .onChange(of: isShowingMFA) { _, newValue in
      if !newValue {
        viewModel.dismissMFAFlow()
      }
    }
    .task(id: viewModel.infoMessage) {
      await autoDismissInfoMessage()
    }
  }

  @ViewBuilder
  private var authContent: some View {
    if viewModel.isSignup {
      SignUpView(viewModel: viewModel)
        .transition(AppTransition.move(edge: .trailing, reduceMotion: reduceMotion))
    } else {
      SignInView(viewModel: viewModel)
        .transition(AppTransition.move(edge: .leading, reduceMotion: reduceMotion))
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
    withAnimation(AppMotion.reduced) {
      viewModel.infoMessage = nil
    }
  }
}
