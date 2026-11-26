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
  @State private var didImport = false
  @State private var opensQOnDisappear = false

  /// Called when an import succeeds, with the portfolio it went into.
  let onImportCompleted: @MainActor (String?) async -> Void

  /// - Parameters:
  ///   - portfolioListId: the portfolio the user came from; nil picks the default.
  ///   - allowsAskQ: false where Q is not reachable (onboarding).
  init(
    portfolioListId: String?,
    allowsAskQ: Bool = true,
    onImportCompleted: @escaping @MainActor (String?) async -> Void
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
      .sheet(item: $presentedMethod, onDismiss: closeAfterImport) { method in
        childSheet(for: method)
      }
    }
    // Ask Q presents the assistant from the tab shell, so wait until this
    // sheet is really gone.
    .onDisappear {
      guard opensQOnDisappear else { return }
      opensQOnDisappear = false
      NotificationCenter.default.post(name: .openAssistant, object: nil)
    }
  }

  @ViewBuilder
  private func childSheet(for method: ImportMethod) -> some View {
    let listId = viewModel.selectedPortfolioListId
    let completed: @MainActor () async -> Void = {
      didImport = true
      await onImportCompleted(listId)
    }
    switch method {
    case .csv:
      PortfolioCSVImportSheet(
        portfolioListId: listId,
        lockedProvider: BrokerImportCatalog.csvProvider,
        onImportCompleted: completed
      )
    case .screenshot:
      PortfolioScreenshotImportSheet(portfolioListId: listId, onImportCompleted: completed)
    case .askQ:
      EmptyView()
    }
  }

  /// The user has seen the result and closed it: nothing is left to do here.
  private func closeAfterImport() {
    guard didImport else { return }
    dismiss()
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
      Text(viewModel.screenshotGuide)
        .font(.footnote)
        .foregroundStyle(.secondary)
      if viewModel.methods.contains(.askQ) {
        Text(BrokerImportCatalog.askQGuide)
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
            Text(method.label).foregroundStyle(.primary)
          } icon: {
            Image(systemName: method.systemImage)
          }
        }
        .accessibilityIdentifier("brokerImport.method.\(method.rawValue)")
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

  /// The full assistant, as the web's "Ask Q" opens. The sheet closes first;
  /// `onDisappear` then posts the route.
  private func askQ() {
    opensQOnDisappear = true
    dismiss()
  }
}
