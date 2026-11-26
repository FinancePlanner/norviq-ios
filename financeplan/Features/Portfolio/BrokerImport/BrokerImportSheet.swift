import SwiftUI

/// "Import from broker": pick a broker and a portfolio, read a short guide,
/// then choose how to bring the holdings in. The same flow as the web
/// `/portfolio/import` page.
///
/// Every entry point passes `onImportCompleted` so the portfolio it sits on
/// refreshes after an import.
@MainActor
struct BrokerImportSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var viewModel: BrokerImportViewModel
  @State private var presentedMethod: ImportMethod?

  let onImportCompleted: @MainActor () async -> Void

  /// - Parameters:
  ///   - portfolioListId: the portfolio the user came from; nil picks the default.
  ///   - allowsAskQ: false where Q is not reachable (onboarding).
  init(
    portfolioListId: String?,
    allowsAskQ: Bool = true,
    onImportCompleted: @escaping @MainActor () async -> Void
  ) {
    _viewModel = State(
      wrappedValue: BrokerImportViewModel(initialPortfolioListId: portfolioListId, allowsAskQ: allowsAskQ)
    )
    self.onImportCompleted = onImportCompleted
  }

  var body: some View {
    NavigationStack {
      List {
        brokerSection
        if viewModel.portfolios.count > 1 {
          portfolioSection
        }
        guideSection
        methodSection
      }
      .navigationTitle("Import from broker")
      .navigationBarTitleDisplayMode(.inline)
      .accessibilityIdentifier("brokerImportSheet")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
      }
      .task { await viewModel.load() }
      .sheet(item: $presentedMethod) { method in
        switch method {
        case .csv:
          PortfolioCSVImportSheet(
            portfolioListId: viewModel.selectedPortfolioListId,
            onImportCompleted: onImportCompleted
          )
        default:
          PortfolioScreenshotImportSheet(
            portfolioListId: viewModel.selectedPortfolioListId,
            onImportCompleted: onImportCompleted
          )
        }
      }
    }
  }

  private var brokerSection: some View {
    Section("Broker") {
      ForEach(BrokerImportCatalog.brokers) { broker in
        Button {
          viewModel.selectedBrokerId = broker.id
        } label: {
          HStack {
            Text(verbatim: broker.name)
              .foregroundStyle(.primary)
            Spacer()
            if broker.id == viewModel.selectedBroker.id {
              Image(systemName: "checkmark")
                .foregroundStyle(AppTheme.Colors.tint)
            }
          }
          .contentShape(Rectangle())
        }
        .accessibilityAddTraits(broker.id == viewModel.selectedBroker.id ? .isSelected : [])
        .accessibilityIdentifier("brokerImport.broker.\(broker.id)")
      }
    }
  }

  private var portfolioSection: some View {
    Section("Portfolio") {
      Picker("Import into", selection: $viewModel.selectedPortfolioListId) {
        ForEach(viewModel.portfolios) { portfolio in
          Text(verbatim: portfolio.name).tag(Optional(portfolio.id))
        }
      }
      .pickerStyle(.menu)
      .accessibilityIdentifier("brokerImport.portfolioPicker")
    }
  }

  @ViewBuilder
  private var guideSection: some View {
    Section("How it works") {
      if viewModel.methods.contains(.csv) {
        CSVImportFormatHint()
      }
      Text(verbatim: viewModel.screenshotGuide)
        .font(.footnote)
        .foregroundStyle(.secondary)
      if viewModel.methods.contains(.askQ) {
        Text(verbatim: BrokerImportCatalog.askQGuide)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var methodSection: some View {
    Section("Method") {
      ForEach(viewModel.methods, id: \.self) { method in
        Button {
          choose(method)
        } label: {
          Label {
            Text(verbatim: method.label).foregroundStyle(.primary)
          } icon: {
            Image(systemName: method.systemImage)
          }
        }
        .accessibilityIdentifier("brokerImport.method.\(method)")
      }
    }
  }

  private func choose(_ method: ImportMethod) {
    switch method {
    case .screenshot, .csv:
      presentedMethod = method
    case .askQ:
      askQ()
    }
  }

  /// Q is mounted once, on `HomeScreen`, which opens it for this notification
  /// from the tabs and from inside Settings alike (it closes Settings first).
  /// The sheet closes first so the two presentations do not race.
  private func askQ() {
    dismiss()
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(450))
      NotificationCenter.default.post(name: .openAssistantFromPushNotification, object: nil)
    }
  }
}

extension ImportMethod: Identifiable {
  var id: String { label }
}
