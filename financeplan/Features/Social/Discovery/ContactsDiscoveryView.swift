import Contacts
import Factory
import SwiftUI
import UIKit

/// "Find friends from contacts": explains what happens, asks for Contacts
/// access, hashes the email addresses on device and shows who is on Norviq.
struct ContactsDiscoveryView: View {
  @Environment(\.dismiss) private var dismiss
  @InjectedObservable(\Container.socialStore) private var store
  @State private var phase: Phase = .explainer
  private let service: any SocialServicing = Container.shared.socialService()

  enum Phase: Equatable {
    case explainer
    case searching
    case results([SocialUserSummary])
    case denied
    case failed(String)
  }

  var body: some View {
    NavigationStack {
      content
        .navigationTitle("Contacts")
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
        Image(systemName: "person.crop.circle.badge.checkmark")
          .font(.system(size: 56))
          .foregroundStyle(AppTheme.Colors.tint)
        Text("Find friends from your contacts")
          .typography(.headline)
          .multilineTextAlignment(.center)
        Text("Norviq turns the email addresses in your contacts into one-way codes on this iPhone and checks them against people who allow it. Your contacts aren't uploaded or stored.")
          .typography(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        Button {
          Task { await run() }
        } label: {
          Text("Continue").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
      }
      .padding(24)
    case .searching:
      ProgressView("Checking your contacts…")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case let .results(users):
      List {
        if users.isEmpty {
          Text("None of your contacts are on Norviq yet. Invite them with your link.")
            .foregroundStyle(.secondary)
        }
        ForEach(users) { user in
          SocialUserRow(user: user) { FriendActionButton(user: user) }
        }
      }
    case .denied:
      ContentUnavailableView {
        Label("Contacts access is off", systemImage: "person.crop.circle.badge.xmark")
      } description: {
        Text("Allow Contacts for Norviq in Settings to find friends this way.")
      } actions: {
        Button("Open Settings") {
          if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
          }
        }
      }
    case let .failed(message):
      ErrorRetryView(message: message) { Task { await run() } }
    }
  }

  private func run() async {
    guard let pepper = store.config.contactPepper, store.config.contactHashVersion == ContactHashing.version else {
      phase = .failed(String(localized: "Contact matching isn't available right now."))
      return
    }
    phase = .searching
    do {
      guard let emails = try await Self.contactEmailAddresses() else {
        phase = .denied
        return
      }
      var found: [String: SocialUserSummary] = [:]
      for batch in ContactHashing.batches(emails: emails, pepper: pepper) {
        let matches = try await service.matchContacts(ContactMatchRequest(hashVersion: ContactHashing.version, items: batch))
        for match in matches { found[match.user.id] = match.user }
      }
      phase = .results(found.values.sorted { $0.sortName.localizedCaseInsensitiveCompare($1.sortName) == .orderedAscending })
    } catch {
      phase = .failed(error.localizedDescription)
    }
  }

  /// Asks for access, then reads only email addresses. Nil when access is
  /// denied. `@concurrent` keeps the blocking enumeration off the main actor.
  @concurrent
  private nonisolated static func contactEmailAddresses() async throws -> [String]? {
    let store = CNContactStore()
    guard (try? await store.requestAccess(for: .contacts)) == true else { return nil }
    var emails: [String] = []
    let request = CNContactFetchRequest(keysToFetch: [CNContactEmailAddressesKey as CNKeyDescriptor])
    try store.enumerateContacts(with: request) { contact, _ in
      emails.append(contentsOf: contact.emailAddresses.map { $0.value as String })
    }
    return emails
  }
}
