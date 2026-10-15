import Factory
import SwiftUI

/// Explicit opt-in before Norviq sends user data to third-party AI providers
/// (App Store Guideline 5.1.2(i)). "Allow" records consent on the server;
/// "Not now" leaves AI features off and does not ask again on entry.
struct AIConsentSheet: View {
  /// Closes the sheet. Presented from UIKit by `AIConsentPresenter`, so the
  /// SwiftUI `dismiss` action is not the way out.
  let onClose: () -> Void

  @InjectedObservable(\.aiConsentStore) private var store

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Image(systemName: "sparkles")
            .font(.largeTitle.bold())
            .foregroundStyle(.tint)
            .accessibilityHidden(true)

          Text("Share data with AI?")
            .font(.title2.weight(.semibold))

          Text(
            "Norviq's AI features send some of your data to Anthropic and OpenRouter, the AI providers that generate the answers."
          )
          .foregroundStyle(.secondary)

          sentSection
          promisesSection

          Link(destination: Constants.Norviq.aiPrivacyUrl) {
            Label("How AI uses your data", systemImage: "arrow.up.right.square")
              .font(.subheadline)
          }

          if let errorMessage = store.errorMessage {
            Text(errorMessage)
              .font(.footnote)
              .foregroundStyle(.red)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
      }
      .safeAreaInset(edge: .bottom) { actions }
      .navigationTitle("AI features")
      .navigationBarTitleDisplayMode(.inline)
    }
    .interactiveDismissDisabled(store.isSaving)
    // A failure from an earlier attempt is not this attempt's error.
    .onAppear { store.clearError() }
  }

  private var sentSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("What is sent")
        .font(.headline)
      Label("Portfolio totals and holdings", systemImage: "chart.pie")
      Label("Spending and budgets", systemImage: "creditcard")
      Label("Receipt and screenshot images you import", systemImage: "photo")
      Label("Your messages to the assistant", systemImage: "bubble.left")
    }
    .font(.subheadline)
  }

  private var promisesSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Not used to train AI models", systemImage: "checkmark.shield")
      Label("Your name and email are not sent", systemImage: "person.crop.circle.badge.xmark")
      Label("Turn it off anytime in Assistant settings", systemImage: "slider.horizontal.3")
    }
    .font(.subheadline)
    .foregroundStyle(.secondary)
  }

  private var actions: some View {
    VStack(spacing: 8) {
      Button {
        Task {
          if await store.allow() { onClose() }
        }
      } label: {
        Group {
          if store.isSaving {
            ProgressView()
          } else {
            Text("Allow")
          }
        }
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(store.isSaving)
      .accessibilityIdentifier("aiConsent.allow")

      Button("Not now") {
        store.decline()
        onClose()
      }
      .frame(maxWidth: .infinity)
      .disabled(store.isSaving)
      .accessibilityIdentifier("aiConsent.notNow")
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 12)
    .background(.bar)
  }
}
