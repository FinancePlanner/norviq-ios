import Factory
import SwiftUI

struct SocialPrivacySettingsView: View {
  @InjectedObservable(\Container.socialStore) private var store
  @State private var settings: SocialPrivacySettings?
  @State private var errorMessage: String?
  @State private var facebookNotice: String?
  @State private var isDisconnectingFacebook = false
  /// Set around writes that come from the server, so they aren't saved back.
  @State private var isApplyingServerValue = false
  private let service: any SocialServicing = Container.shared.socialService()

  var body: some View {
    Form {
      if let binding = Binding($settings) {
        Section {
          Picker("Who can find me", selection: binding.searchVisibility) {
            ForEach(SearchVisibility.allCases) { option in
              Text(option.title).tag(option)
            }
          }
          Toggle("Find me from contacts", isOn: binding.discoverableByContacts)
          Toggle("Find me from X", isOn: binding.discoverableByX)
          if store.config.facebookImport {
            Toggle("Find me from Facebook", isOn: binding.discoverableByFacebook)
          }
        } header: {
          Text("Discovery")
        }

        if store.config.facebookImport {
          Section {
            Button("Disconnect Facebook", role: .destructive) {
              Task { await disconnectFacebook() }
            }
            .disabled(isDisconnectingFacebook)
          } footer: {
            Text("Removes the Facebook link used to find friends. Your Facebook friends on Norviq stop finding you this way.")
          }
        }

        Section {
          Toggle("Show my return %", isOn: binding.showReturnPercent)
          Toggle("Show my streaks", isOn: binding.showStreaks)
          Toggle("Show my XP and level", isOn: binding.showXP)
          Toggle("Appear on friends' leaderboards", isOn: binding.leaderboardOptIn)
        } header: {
          Text("What friends see")
        } footer: {
          Text("Only friends see these. Amounts of money are never shared, only percentages.")
        }
      } else if let errorMessage {
        ErrorRetryView(message: errorMessage) { Task { await load() } }
      } else {
        ProgressView().frame(maxWidth: .infinity)
      }
    }
    .navigationTitle("Privacy")
    .alert(
      "Facebook",
      isPresented: Binding(get: { facebookNotice != nil }, set: { if !$0 { facebookNotice = nil } })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(facebookNotice ?? "")
    }
    .task { await load() }
    .onChange(of: settings) { old, new in
      if isApplyingServerValue {
        isApplyingServerValue = false
        return
      }
      guard let old, let new, old != new else { return }
      Task { await save(new, revertingTo: old) }
    }
  }

  private func load() async {
    errorMessage = nil
    do {
      let loaded = try await service.privacy()
      if settings != nil { isApplyingServerValue = true }
      settings = loaded
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func disconnectFacebook() async {
    isDisconnectingFacebook = true
    defer { isDisconnectingFacebook = false }
    do {
      try await service.disconnectFacebook()
      FacebookConnect.logOut()
      facebookNotice = String(localized: "Facebook is disconnected.")
    } catch {
      facebookNotice = error.localizedDescription
    }
  }

  /// Saves each change as it's made; a failed save puts the switch back so
  /// the screen never shows a setting the server doesn't have.
  private func save(_ new: SocialPrivacySettings, revertingTo old: SocialPrivacySettings) async {
    do {
      let saved = try await service.updatePrivacy(new)
      guard saved != settings else { return }
      isApplyingServerValue = true
      settings = saved
    } catch {
      isApplyingServerValue = true
      settings = old
    }
  }
}
