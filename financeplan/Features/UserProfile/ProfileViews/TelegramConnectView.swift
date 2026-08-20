import SwiftUI

/// Connect, inspect, and disconnect the Telegram bot.
///
/// Linking finishes inside Telegram, not here — this screen hands over a code
/// and then re-checks status when the user comes back.
struct TelegramConnectView: View {
  @State private var viewModel = TelegramLinkViewModel()
  @State private var isConfirmingDisconnect = false
  @Environment(\.openURL) private var openURL

  var body: some View {
    List {
      if viewModel.isLoading, viewModel.status == nil {
        Section {
          HStack {
            ProgressView()
            Text("Loading…")
              .foregroundStyle(.secondary)
          }
        }
      } else if !viewModel.isAvailable {
        Section {
          Text("Telegram isn't available on this build yet.")
            .foregroundStyle(.secondary)
        }
      } else if viewModel.isConnected {
        connectedSection
        if !viewModel.alerts.isEmpty {
          alertsSection
        }
        disconnectSection
      } else {
        connectSection
      }

      if let errorMessage = viewModel.errorMessage {
        Section {
          Text(errorMessage)
            .foregroundStyle(.red)
        }
      }
    }
    .vigilListChrome()
    .vigilScreenBackground()
    .vigilNavigationTitle(LocalizedStringKey("Telegram"))
    .vigilInlineNavigationBar()
    .task { await viewModel.load() }
    .refreshable { await viewModel.load() }
    .confirmationDialog(
      LocalizedStringKey("Disconnect Telegram?"),
      isPresented: $isConfirmingDisconnect,
      titleVisibility: .visible
    ) {
      Button(LocalizedStringKey("Disconnect"), role: .destructive) {
        Task { await viewModel.disconnect() }
      }
      Button(LocalizedStringKey("Cancel"), role: .cancel) {}
    } message: {
      Text(LocalizedStringKey("The bot will stop answering in that chat. Your Norviq account is unaffected."))
    }
  }

  // MARK: - Sections

  private var connectSection: some View {
    Section {
      if let code = viewModel.pairingCode {
        VStack(alignment: .leading, spacing: 12) {
          Text(LocalizedStringKey("Send this code to the bot"))
            .font(.subheadline.weight(.semibold))
          Text(code.code)
            .font(.system(.title2, design: .monospaced))
            .tracking(6)
            .textSelection(.enabled)
          Text(LocalizedStringKey("Shown once. Generate a new one if you lose it."))
            .font(.caption)
            .foregroundStyle(.secondary)
          Button {
            viewModel.openTelegram(using: openURL)
          } label: {
            Label(LocalizedStringKey("Open Telegram"), systemImage: "arrow.up.forward.app")
          }
          .accessibilityIdentifier("integrations.telegram.open")
        }
        .padding(.vertical, 4)
      } else {
        Button {
          Task { await viewModel.connect() }
        } label: {
          if viewModel.isWorking {
            ProgressView()
          } else {
            Text(LocalizedStringKey("Connect Telegram"))
          }
        }
        .disabled(viewModel.isWorking)
        .accessibilityIdentifier("integrations.telegram.connect")
      }
    } header: {
      Text(LocalizedStringKey("Telegram"))
    } footer: {
      Text(LocalizedStringKey("Ask Norviq from Telegram — the same assistant and the same conversation as in the app. Proposed changes still wait for you to confirm them."))
    }
  }

  private var connectedSection: some View {
    Section {
      LabeledContent(LocalizedStringKey("Bot"), value: viewModel.botHandle)
      if let lastSeen = viewModel.status?.lastSeenAt {
        LabeledContent(LocalizedStringKey("Last message"), value: lastSeen.formatted(.relative(presentation: .named)))
      } else if let connectedAt = viewModel.status?.connectedAt {
        LabeledContent(LocalizedStringKey("Connected"), value: connectedAt.formatted(.relative(presentation: .named)))
      }
    } header: {
      Text(LocalizedStringKey("Connection"))
    }
  }

  /// Every alert defaults to off. A new alert kind must never start messaging
  /// someone who did not ask for it.
  private var alertsSection: some View {
    Section {
      ForEach(viewModel.alerts) { alert in
        Toggle(alert.label, isOn: Binding(
          get: { alert.enabled },
          set: { newValue in
            Task { await viewModel.setAlert(kind: alert.kind, enabled: newValue) }
          }
        ))
        .disabled(viewModel.isWorking)
      }
    } header: {
      Text(LocalizedStringKey("Alerts to Telegram"))
    } footer: {
      Text(LocalizedStringKey("Alerts you turn on here are delivered to your chat as well as to this device."))
    }
  }

  private var disconnectSection: some View {
    Section {
      Button(role: .destructive) {
        isConfirmingDisconnect = true
      } label: {
        Text(LocalizedStringKey("Disconnect"))
      }
      .disabled(viewModel.isWorking)
      .accessibilityIdentifier("integrations.telegram.disconnect")
    }
  }
}
