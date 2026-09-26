import Factory
import StockPlanShared
import SwiftUI

/// "Find friends you follow on X": signs in to X for this one lookup (the
/// server drops the token straight after) and lists the people already here.
struct XImportView: View {
  @Environment(\.dismiss) private var dismiss
  @InjectedObservable(\Container.appEnvironment) private var environmentManager
  @State private var phase: Phase = .explainer
  private let service: any SocialServicing = Container.shared.socialService()
  private let webAuthenticator: any OAuthWebAuthenticating = OAuthWebAuthenticator()

  enum Phase: Equatable {
    case explainer
    case working
    case results(XImportMatchesResponse)
    case failed(String)
  }

  var body: some View {
    NavigationStack {
      content
        .navigationTitle("Friends from X")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
          }
        }
    }
  }

  @ViewBuilder
  private var content: some View {
    switch phase {
    case .explainer:
      VStack(spacing: 20) {
        Image(systemName: "person.2.wave.2")
          .font(.system(size: 56))
          .foregroundStyle(AppTheme.Colors.tint)
        Text("Find people you follow on X")
          .typography(.headline)
          .multilineTextAlignment(.center)
        Text("Sign in to X to let Norviq read who you follow, once. We match them against people who connected X here and allow it, and don't keep access to your X account.")
          .typography(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        Button {
          Task { await run() }
        } label: {
          Text("Continue with X").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
      }
      .padding(24)
    case .working:
      ProgressView("Looking for people you follow…")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case let .results(response):
      List {
        Section {
          if response.matches.isEmpty {
            Text("None of the people you follow are on Norviq yet.")
              .foregroundStyle(.secondary)
          }
          ForEach(response.matches) { match in
            SocialUserRow(user: match.user) { FriendActionButton(user: match.user) }
          }
        } footer: {
          Text("Checked \(response.totalFollowingScanned) accounts you follow.")
        }
      }
    case let .failed(message):
      ErrorRetryView(message: message) { Task { await run() } }
    }
  }

  private func run() async {
    let callbackScheme = Self.callbackScheme()
    let redirectURI = Self.redirectURI(apiBaseURL: environmentManager.current.apiBaseUrl)
    do {
      let start = try await service.startXImport(redirectURI: redirectURI)
      guard let url = URL(string: start.authorizationURL) else {
        throw OAuthWebAuthenticationError.invalidAuthorizationURL
      }
      let callback = try await webAuthenticator.authenticate(url: url, callbackScheme: callbackScheme)
      phase = .working
      let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
      guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
        throw OAuthWebAuthenticationError.missingCode
      }
      guard let state = items.first(where: { $0.name == "state" })?.value, !state.isEmpty else {
        throw OAuthWebAuthenticationError.missingState
      }
      let response = try await service.finishXImport(
        OAuthExchangeRequestPayload(flowId: start.flowId, code: code, state: state, redirectURI: redirectURI)
      )
      phase = .results(response)
    } catch OAuthWebAuthenticationError.cancelled {
      phase = .explainer
    } catch {
      phase = .failed(error.localizedDescription)
    }
  }

  /// Same callback as linking X in Settings: X redirects to the API's https
  /// bridge, which bounces to the app scheme. That URI is already on the
  /// server's redirect allowlist.
  static func redirectURI(apiBaseURL: URL) -> String {
    let host = apiBaseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return "\(host)/v1/auth/oauth/x/callback"
  }

  static func callbackScheme() -> String {
    let configured = (Bundle.main.object(forInfoDictionaryKey: "OAuthCallbackScheme") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let configured, !configured.isEmpty else { return "norviqa" }
    return configured
  }
}
