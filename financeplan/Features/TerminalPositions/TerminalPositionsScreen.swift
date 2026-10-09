import Factory
import StockPlanShared
import SwiftUI

struct TerminalPositionsScreen: View {
  @State private var model = TerminalPositionsViewModel(service: Container.shared.terminalPositionsService())
  @AppStorage(TerminalPreferences.roundDownKey) private var roundDown = false
  @State private var editorTarget: TerminalEditorTarget?
  @State private var autobuyTarget: AutobuyEditorTarget?

  var body: some View {
    List {
      headerSection
      if model.positions.isEmpty {
        if model.showsSample {
          sampleSection
        } else if model.hasLoaded {
          Section {
            Text("No positions yet. Tap + to add your first scenario.")
              .foregroundStyle(.secondary)
          }
        }
      } else {
        positionsSection
        totalsSection
      }
      TerminalAutobuysSection(
        model: model,
        onEdit: { autobuyTarget = .edit($0) },
        onAdd: { autobuyTarget = .new }
      )
    }
    .vigilListChrome()
    .vigilScreenBackground()
    .navigationTitle("Terminal positions")
    .vigilInlineNavigationBar()
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        if model.positions.count > 1 {
          EditButton()
        }
        Button("Add position", systemImage: "plus") { editorTarget = .new(ticker: nil) }
      }
    }
    .overlay {
      if model.isLoading && !model.hasLoaded {
        ProgressView()
      }
    }
    .task { await model.load() }
    .refreshable { await model.load() }
    .sheet(item: $editorTarget) { target in
      TerminalPositionEditorSheet(target: target, currency: model.currency) { model.saved($0) }
    }
    .sheet(item: $autobuyTarget) { target in
      AutobuyEditorSheet(target: target, currency: model.currency) { _ in
        Task { await model.reloadAutobuys() }
      }
    }
    .alert("Terminal position sizing", isPresented: errorBinding) {
      Button("OK", role: .cancel) { model.errorMessage = nil }
    } message: {
      Text(model.errorMessage ?? "")
    }
  }

  private var errorBinding: Binding<Bool> {
    Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
  }

  private var headerSection: some View {
    Section {
      VStack(alignment: .leading, spacing: 6) {
        Text(TerminalCopy.title)
          .font(.title2.bold())
        Text(TerminalCopy.subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Toggle("Round down to whole shares", isOn: $roundDown)
    } footer: {
      Text(TerminalCopy.disclaimer)
    }
  }

  private var positionsSection: some View {
    Section {
      ForEach(model.positions) { position in
        Button {
          editorTarget = .edit(position)
        } label: {
          TerminalPositionRow(position: position, currency: model.currency, roundDown: roundDown)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
          Button("Delete", role: .destructive) {
            Task { await model.delete(position) }
          }
        }
        .swipeActions(edge: .leading) {
          Button("Duplicate", systemImage: "plus.square.on.square") {
            Task { await model.duplicate(position) }
          }
          .tint(.blue)
        }
      }
      .onMove { source, destination in
        _ = model.move(fromOffsets: source, toOffset: destination)
      }
    } header: {
      Text("Positions")
    }
  }

  private var totalsSection: some View {
    let totals = model.totals
    return Section {
      LabeledContent("Total value wanted") {
        Text(TerminalFormat.money(totals.valueWanted, currency: model.currency)).monospacedDigit()
      }
      LabeledContent("Still needed at terminal prices") {
        Text(TerminalFormat.money(totals.gapValueAtTerminal, currency: model.currency)).monospacedDigit()
      }
      if let capital = totals.capitalAtTodayPrice {
        LabeledContent("Capital at today's prices") {
          Text(TerminalFormat.money(capital, currency: model.currency)).monospacedDigit()
        }
      }
    } header: {
      Text("Totals")
    }
  }

  private var sampleSection: some View {
    Section {
      if let preview = TerminalPositionsViewModel.samplePreview {
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Text(verbatim: TerminalPositionsViewModel.sampleRequest.ticker)
              .font(.headline)
            Text("Sample")
              .font(.caption.weight(.semibold))
              .padding(.horizontal, 8)
              .padding(.vertical, 2)
              .background(.secondary.opacity(0.15), in: Capsule())
            Spacer()
            Text(TerminalFormat.price(preview.terminalSharePrice, currency: model.currency))
              .font(.headline.monospacedDigit())
          }
          LabeledContent("Shares needed") {
            Text(TerminalFormat.shares(preview.sharesNeeded, roundDown: roundDown))
          }
        }
      }
      HStack {
        Button("Use AMZN sample") { Task { await model.useSample() } }
          .buttonStyle(.borderedProminent)
        Button("Dismiss") { model.dismissSample() }
          .buttonStyle(.bordered)
      }
    } header: {
      Text("Get started")
    }
  }
}

/// Terminal share price and shares needed come first; they are the answer.
struct TerminalPositionRow: View {
  let position: TerminalPositionResponse
  let currency: String
  let roundDown: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        Text(verbatim: position.ticker)
          .font(.headline)
        Spacer()
        if let price = position.terminalSharePrice {
          Text(TerminalFormat.price(price, currency: currency))
            .font(.headline.monospacedDigit())
        }
      }
      if let error = position.scenarioError {
        Label(TerminalPositionEditorModel.text(forRaw: error), systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.orange)
      } else if let needed = position.sharesNeeded {
        LabeledContent("Shares needed") {
          Text(TerminalFormat.shares(needed, roundDown: roundDown)).monospacedDigit()
        }
        .font(.subheadline)
        ProgressView(value: min(max(position.progress ?? 0, 0), 1))
        HStack {
          Text(TerminalFormat.progress(position.progress ?? 0))
          Spacer()
          if let still = position.sharesStillNeeded, still > 0 {
            Text("Still needed: \(TerminalFormat.shares(still, roundDown: roundDown))")
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
    .contentShape(Rectangle())
  }
}
