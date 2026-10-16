import Factory
import SwiftUI

/// Settings › Alerts row for the market brief push. Turning it on also turns
/// push notifications on, asking for permission when needed.
struct MarketBriefAlertsToggle: View {
  @InjectedObservable(\Container.marketBriefAlertsStore) private var store
  @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.english.rawValue
  @State private var isOn = false

  private var language: String {
    AppLanguage.from(appLanguageRawValue).rawValue
  }

  var body: some View {
    Toggle(isOn: $isOn) {
      Label(LocalizedStringKey("Market brief alerts"), systemImage: "sunrise")
    }
    .disabled(store.isLoading)
    .onChange(of: store.isEnabled, initial: true) { _, enabled in
      isOn = enabled
    }
    .onChange(of: isOn) { _, enabled in
      // Only the reader's own flips go to the server, not the sync above.
      guard enabled != store.isEnabled else { return }
      Task { await store.setEnabled(enabled, language: language) }
    }
    .task {
      await store.load(language: language)
    }

    if let error = store.errorMessage, !error.isEmpty {
      Text(error)
        .typography(.caption)
        .foregroundStyle(AppTheme.Colors.danger)
    }
  }
}
