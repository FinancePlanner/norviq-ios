import Factory
import SwiftUI

struct SocialPrivacySettingsView: View {
  @State private var settings: SocialPrivacySettings?
  @State private var errorMessage: String?
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
        } header: {
          Text("Discovery")
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
