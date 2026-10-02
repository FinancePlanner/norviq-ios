import Factory
import SwiftUI

/// "Find friends from Facebook": Limited Login once, then the server lists
/// the friends Facebook shares, which are only those who also connected
/// Facebook to Norviq. Anyone else is reached with the invite link.
struct FacebookImportView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var phase: Phase = .explainer
  @State private var isDisconnecting = false
  @State private var disconnectError: String?
  private let service: any SocialServicing = Container.shared.socialService()

  enum Phase: Equatable {
    case explainer
    case working
    case results(FacebookImportMatchesResponse)
    case failed(String)
  }

  var body: some View {
    NavigationStack {
      content
        .navigationTitle("Friends from Facebook")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
          }
        }
        .alert(
          "Couldn't disconnect Facebook",
          isPresented: Binding(get: { disconnectError != nil }, set: { if !$0 { disconnectError = nil } })
        ) {
          Button("OK", role: .cancel) {}
        } message: {
          Text(disconnectError ?? "")
        }
    }
  }

  @ViewBuilder
  private var content: some View {
    switch phase {
    case .explainer:
      VStack(spacing: 20) {
        Image(systemName: "person.2.badge.key")
          .font(.system(size: 56))
          .foregroundStyle(AppTheme.Colors.tint)
        Text("Find friends from Facebook")
          .typography(.headline)
          .multilineTextAlignment(.center)
        Text("Norviq sees only your friends who also connected Facebook to Norviq. Nothing is posted to Facebook.")
          .typography(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        Button {
          Task { await run() }
        } label: {
          Text("Continue with Facebook").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
      }
      .padding(24)
    case .working:
      ProgressView("Looking for your Facebook friends…")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case let .results(response):
      List {
        Section {
          if response.matches.isEmpty {
            Text("None of your Facebook friends are on Norviq yet. Friends show up here once they connect Facebook to Norviq too.")
              .foregroundStyle(.secondary)
          }
          ForEach(response.matches) { match in
            SocialUserRow(user: match.user) { FriendActionButton(user: match.user) }
          }
        } footer: {
          Text("Norviq sees only your friends who also connected Facebook to Norviq. Nothing is posted to Facebook.")
        }

        Section {
          Button("Disconnect Facebook", role: .destructive) {
            Task { await disconnect() }
          }
          .disabled(isDisconnecting)
        } footer: {
          Text("Your Facebook friends on Norviq stop finding you this way.")
        }
      }
    case let .failed(message):
      ErrorRetryView(message: message) { Task { await run() } }
    }
  }

  private func run() async {
    do {
      let (token, nonce) = try await FacebookConnect.logIn()
      phase = .working
      let response = try await service.importFacebookFriends(FacebookLimitedLoginRequest(idToken: token, nonce: nonce))
      phase = .results(response)
    } catch FacebookConnect.Failure.cancelled {
      phase = .explainer
    } catch {
      phase = .failed(Self.message(for: error))
    }
  }

  private func disconnect() async {
    isDisconnecting = true
    defer { isDisconnecting = false }
    do {
      try await service.disconnectFacebook()
      FacebookConnect.logOut()
      phase = .explainer
    } catch {
      disconnectError = error.localizedDescription
    }
  }

  /// The server explains a 409 itself; this covers one that arrives without
  /// a reason.
  static func message(for error: any Error) -> String {
    if let error = error as? SocialHTTPClient.Error, error.statusCode == 409 {
      return String(localized: "This Facebook account is already connected to another Norviq account.")
    }
    return error.localizedDescription
  }
}
