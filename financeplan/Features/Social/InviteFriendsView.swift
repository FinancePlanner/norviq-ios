import Factory
import UIKit
import SwiftUI

/// The user's invite link as a QR code and a share sheet. Instagram and
/// Facebook have no friends API, so this link is how people there join.
struct InviteFriendsView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var invite: InviteLink?
  @State private var errorMessage: String?
  @State private var didCopy = false
  private let service: any SocialServicing = Container.shared.socialService()

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          if let invite, let url = URL(string: invite.url) {
            qrCode(for: url)
            Text(invite.url)
              .typography(.caption)
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
            ShareLink(
              item: url,
              subject: Text("Join me on Norviq"),
              message: Text("Let's track our goals together on Norviq: \(url.absoluteString)")
            ) {
              Label("Share invite link", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button {
              UIPasteboard.general.url = url
              didCopy = true
            } label: {
              Label(didCopy ? "Copied" : "Copy link", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
          } else if let errorMessage {
            ErrorRetryView(message: errorMessage) { Task { await load() } }
          } else {
            ProgressView().padding(.top, 80)
          }
        }
        .padding(24)
      }
      .navigationTitle("Invite friends")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }
      }
      .task { if invite == nil { await load() } }
    }
  }

  @ViewBuilder
  private func qrCode(for url: URL) -> some View {
    if let image = QRCodeGenerator.image(for: url.absoluteString) {
      Image(uiImage: image)
        .interpolation(.none)
        .resizable()
        .scaledToFit()
        .frame(width: 220, height: 220)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityLabel("QR code for your invite link")
    }
  }

  private func load() async {
    errorMessage = nil
    do {
      invite = try await service.createInvite()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

/// Shown when an invite link opened the app: who invited you, and one tap to connect.
struct InviteRedeemSheet: View {
  let code: String
  @InjectedObservable(\Container.socialStore) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var inviter: SocialUserSummary?
  @State private var errorMessage: String?
  @State private var isRedeeming = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        if let inviter {
          SocialAvatar(user: inviter, size: 96)
          Text("\(inviter.title) invited you to be friends on Norviq")
            .typography(.headline)
            .multilineTextAlignment(.center)
          Button {
            redeem()
          } label: {
            Text("Add friend").frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .disabled(isRedeeming)
        } else if let errorMessage {
          ContentUnavailableView(
            "This invite doesn't work",
            systemImage: "link.badge.plus",
            description: Text(errorMessage)
          )
        } else {
          ProgressView()
        }
      }
      .padding(24)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Not now") { dismiss() }
        }
      }
      .task { await loadPreview() }
    }
    .presentationDetents([.medium])
  }

  private func loadPreview() async {
    do {
      inviter = try await store.invitePreview(code: code)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func redeem() {
    Task {
      isRedeeming = true
      defer { isRedeeming = false }
      if await store.redeemInvite(code: code) { dismiss() }
    }
  }
}
