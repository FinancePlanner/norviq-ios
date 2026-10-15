import Factory
import SwiftUI

extension View {
  /// Gates an AI surface on the user's AI data-sharing consent.
  ///
  /// While the server says the user has not consented, the surface is replaced
  /// by an explanation with a way to allow; on first entry the consent sheet
  /// is presented. An unknown consent state (not loaded, or the read failed)
  /// never blocks — the backend enforces it, and a `403 AI_CONSENT_REQUIRED`
  /// from any AI call presents the sheet app-wide (`AIConsentPresenter`).
  ///
  /// Apply it inside the surface's `NavigationStack`, before `.toolbar`, so
  /// Close/Cancel stay reachable in the disabled state.
  func aiConsentGate(_ feature: LocalizedStringKey) -> some View {
    modifier(AIConsentGateModifier(feature: feature))
  }

  /// Presents the consent sheet when `isPresented` is set, without hiding the
  /// view. For screens where only one action uses AI. (Server-driven prompts
  /// need nothing here: they are presented app-wide.)
  func aiConsentPrompt(isPresented: Binding<Bool>) -> some View {
    modifier(AIConsentPromptModifier(isPresented: isPresented))
  }
}

private struct AIConsentGateModifier: ViewModifier {
  let feature: LocalizedStringKey

  @InjectedObservable(\.aiConsentStore) private var store
  @State private var isVisible = false

  func body(content: Content) -> some View {
    Group {
      if store.allowsAI {
        content
      } else {
        AIConsentDisabledView(feature: feature) { store.requestPrompt() }
      }
    }
    .onAppear {
      isVisible = true
      autoPromptIfNeeded()
    }
    .onDisappear { isVisible = false }
    // Entering an AI surface re-reads a flag that is unknown or stale.
    .task { await store.refreshIfStale() }
    .onChange(of: store.status) { _, _ in autoPromptIfNeeded() }
  }

  /// Only from a surface on screen: a gated tab in the background must not
  /// pop the sheet over whatever the user is doing.
  private func autoPromptIfNeeded() {
    guard isVisible, store.shouldAutoPrompt else { return }
    store.requestPrompt()
  }
}

private struct AIConsentPromptModifier: ViewModifier {
  @Binding var isPresented: Bool

  @InjectedObservable(\.aiConsentStore) private var store

  func body(content: Content) -> some View {
    content
      .onChange(of: isPresented) { _, requested in
        guard requested else { return }
        isPresented = false
        store.requestPrompt()
      }
  }
}

/// What an AI surface shows after "Not now", or after sharing was turned off.
private struct AIConsentDisabledView: View {
  let feature: LocalizedStringKey
  let onAllow: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label(feature, systemImage: "sparkles")
    } description: {
      Text("AI features are off. They need your permission to send data to Norviq's AI providers, Anthropic and OpenRouter.")
    } actions: {
      Button("Review and allow", action: onAllow)
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("aiConsent.review")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
