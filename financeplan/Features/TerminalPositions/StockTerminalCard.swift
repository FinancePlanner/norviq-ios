import Factory
import Observation
import StockPlanShared
import SwiftUI

@MainActor @Observable
final class StockTerminalCardModel {
  enum State: Equatable {
    case loading
    /// Failure collapses the card instead of erroring the stock tab.
    case hidden
    case empty(currency: String)
    case position(TerminalPositionResponse, currency: String)
  }

  private(set) var state: State = .loading
  private var loadedSymbol: String?
  private let service: any TerminalPositionsServicing

  init(service: any TerminalPositionsServicing = Container.shared.terminalPositionsService()) {
    self.service = service
  }

  var currency: String {
    switch state {
    case let .empty(currency), let .position(_, currency): currency
    case .loading, .hidden: "USD"
    }
  }

  func load(symbol: String) async {
    // A row for another ticker is never shown (or edited) under this one.
    if loadedSymbol != symbol { state = .loading }
    loadedSymbol = symbol
    do {
      let list = try await service.list(ticker: symbol)
      state = list.positions.first.map { .position($0, currency: list.currency) } ?? .empty(currency: list.currency)
    } catch {
      guard !TerminalPositionsErrorText.isCancellation(error) else { return }
      state = .hidden
    }
  }

  func saved(_ position: TerminalPositionResponse) {
    state = .position(position, currency: currency)
  }
}

/// That ticker's first terminal scenario on the stock overview tab, or a way
/// to add one. Self-loading like `StockPressureCard`.
struct StockTerminalCard: View {
  let symbol: String
  @AppStorage(TerminalPreferences.roundDownKey) private var roundDown = false
  @State private var model = StockTerminalCardModel()
  @State private var editorTarget: TerminalEditorTarget?

  var body: some View {
    // The task lives on a host that always exists: `.hidden` renders nothing,
    // and a task on nothing never runs again.
    ZStack {
      Color.clear.frame(width: 0, height: 0)
        .task(id: symbol) { await model.load(symbol: symbol) }
      card
    }
    .sheet(item: $editorTarget) { target in
      TerminalPositionEditorSheet(target: target, currency: model.currency) { model.saved($0) }
    }
  }

  private var card: some View {
    Group {
      switch model.state {
      case .loading:
        GlassCard {
          HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Checking your terminal scenario…")
              .typography(.small)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      case .hidden:
        EmptyView()
      case .empty:
        GlassCard {
          VStack(alignment: .leading, spacing: 10) {
            Text("Terminal scenario")
              .typography(.small, weight: .semibold)
            Button {
              editorTarget = .new(ticker: symbol)
            } label: {
              Label("Add terminal scenario", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      case let .position(position, currency):
        GlassCard { content(position, currency: currency) }
      }
    }
  }

  private func content(_ position: TerminalPositionResponse, currency: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Terminal scenario")
          .typography(.small, weight: .semibold)
        Spacer()
        Button("Edit") { editorTarget = .edit(position) }
          .font(.caption.weight(.semibold))
      }
      if let error = position.scenarioError {
        Label(TerminalPositionEditorModel.text(forRaw: error), systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.orange)
      } else {
        if let price = position.terminalSharePrice {
          LabeledContent("Terminal share price") {
            Text(TerminalFormat.price(price, currency: currency)).monospacedDigit()
          }
        }
        if let needed = position.sharesNeeded {
          LabeledContent("Shares needed") {
            Text(TerminalFormat.shares(needed, roundDown: roundDown)).monospacedDigit()
          }
        }
        ProgressView(value: min(max(position.progress ?? 0, 0), 1))
          .accessibilityLabel(Text("Progress"))
          .accessibilityValue(Text(TerminalFormat.progress(position.progress ?? 0)))
        Text(TerminalFormat.progress(position.progress ?? 0))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Text(TerminalCopy.disclaimer)
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
  }
}
