import Factory
import StockPlanShared
import SwiftUI

enum TerminalEditorTarget: Identifiable {
  case new(ticker: String?)
  case edit(TerminalPositionResponse)

  var id: String {
    switch self {
    case let .new(ticker): "new-\(ticker ?? "")"
    case let .edit(position): position.id
    }
  }

  var position: TerminalPositionResponse? {
    if case let .edit(position) = self { return position }
    return nil
  }

  var ticker: String? {
    if case let .new(ticker) = self { return ticker }
    return nil
  }
}

/// A number field with an optional K/M/B/T unit menu. Built on `TerminalNumberInput`
/// (MoneyInputParser underneath) rather than `FormTextField`, whose formatter
/// rejects the comma a pt-PT keypad types.
struct TerminalNumberInputField: View {
  let title: LocalizedStringKey
  @Binding var input: TerminalNumberInput
  var showsUnit = false
  var problem: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      HStack {
        TextField(text: $input.text, prompt: Text(verbatim: "0")) { Text(title) }
          .keyboardType(.decimalPad)
          .monospacedDigit()
        if showsUnit {
          Picker(selection: $input.unit) {
            ForEach(TerminalUnit.allCases) { unit in
              Text(verbatim: unit.symbol).tag(unit)
            }
          } label: {
            Text("Unit")
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .fixedSize()
        }
      }
      if let problem {
        Text(problem)
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
  }
}

struct TerminalSourcesList: View {
  let sources: [String]

  var body: some View {
    if !sources.isEmpty {
      VStack(alignment: .leading, spacing: 4) {
        Text("Sources")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        ForEach(sources, id: \.self) { source in
          if let url = URL(string: source), url.scheme == "https" {
            Link(url.host() ?? source, destination: url)
              .font(.caption)
          } else {
            Text(verbatim: source)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }
}

struct TerminalPositionEditorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @InjectedObservable(\Container.billingManager) private var billingManager
  @AppStorage(TerminalPreferences.roundDownKey) private var roundDown = false
  @State private var model: TerminalPositionEditorModel
  @State private var isPaywallPresented = false
  private let onSaved: (TerminalPositionResponse) -> Void

  init(target: TerminalEditorTarget, currency: String, onSaved: @escaping (TerminalPositionResponse) -> Void) {
    _model = State(initialValue: TerminalPositionEditorModel(
      position: target.position,
      ticker: target.ticker,
      currency: currency,
      service: Container.shared.terminalPositionsService()
    ))
    self.onSaved = onSaved
  }

  var body: some View {
    NavigationStack {
      Form {
        tickerSection
        scenarioSection
        holdingSection
        previewSection
        aiSection
        Section("Notes") {
          TextField("Why this scenario?", text: $model.inputs.notes, axis: .vertical)
            .lineLimit(2...6)
        }
      }
      .navigationTitle(model.isEditing ? LocalizedStringKey("Edit position") : LocalizedStringKey("New position"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: dismiss.callAsFunction)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { Task { await save() } }
            .disabled(!model.canSave)
        }
      }
      .alert("Terminal position sizing", isPresented: errorBinding) {
        Button("OK", role: .cancel) { model.errorMessage = nil }
      } message: {
        Text(model.errorMessage ?? "")
      }
      .sheet(isPresented: $isPaywallPresented) {
        PaywallView(billingManager: billingManager)
      }
      .onChange(of: model.needsUpgrade) { _, needsUpgrade in
        guard needsUpgrade else { return }
        model.needsUpgrade = false
        isPaywallPresented = true
      }
    }
  }

  private var errorBinding: Binding<Bool> {
    Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
  }

  private var tickerSection: some View {
    Section {
      TextField("Ticker", text: $model.inputs.ticker)
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()
      if let problem = model.problem(for: .ticker) {
        problemText(problem)
      }
    } header: {
      Text("Company")
    }
  }

  private var scenarioSection: some View {
    Section {
      TerminalNumberInputField(
        title: "Future share count",
        input: $model.inputs.terminalShareCount,
        showsUnit: true,
        problem: model.problem(for: .terminalShareCount)
      )
      TerminalNumberInputField(
        title: "Future market cap",
        input: $model.inputs.terminalMarketCap,
        showsUnit: true,
        problem: model.problem(for: .terminalMarketCap)
      )
      TerminalNumberInputField(
        title: "Value wanted",
        input: $model.inputs.valueWanted,
        showsUnit: true,
        problem: model.problem(for: .valueWanted)
      )
    } header: {
      Text("Your scenario")
    } footer: {
      Text("K, M, B and T are thousands, millions, billions and trillions.")
    }
  }

  private var holdingSection: some View {
    Section {
      TerminalNumberInputField(
        title: "Shares owned",
        input: $model.inputs.sharesOwned,
        problem: model.problem(for: .sharesOwned)
      )
      TerminalNumberInputField(
        title: "Today's share price (optional)",
        input: $model.inputs.currentSharePrice,
        problem: model.problem(for: .currentSharePrice)
      )
      TerminalNumberInputField(
        title: "Shares outstanding today (optional)",
        input: $model.inputs.sharesOutstanding,
        showsUnit: true,
        problem: model.problem(for: .sharesOutstanding)
      )
    } header: {
      Text("Where you are now")
    }
  }

  private var previewSection: some View {
    Section {
      if let result = model.previewResult {
        LabeledContent("Terminal share price") {
          Text(TerminalFormat.price(result.terminalSharePrice, currency: model.currency))
        }
        LabeledContent("Shares needed") {
          Text(TerminalFormat.shares(result.sharesNeeded, roundDown: roundDown))
        }
        LabeledContent("Progress") {
          Text(TerminalFormat.progress(result.progress))
        }
        ProgressView(value: min(max(result.progress, 0), 1))
        LabeledContent("Still needed") {
          Text(TerminalFormat.shares(result.sharesStillNeeded, roundDown: roundDown))
        }
        LabeledContent("Gap at terminal price") {
          Text(TerminalFormat.money(result.gapValueAtTerminal, currency: model.currency))
        }
        if let capital = result.capitalAtTodayPrice {
          LabeledContent("Cost at today's price") {
            Text(TerminalFormat.money(capital, currency: model.currency))
          }
        }
        Toggle("Round down to whole shares", isOn: $roundDown)
      } else if case let .failure(error)? = model.preview {
        problemText(TerminalPositionEditorModel.text(for: error))
      } else {
        Text("Enter share count, market cap and value wanted to see the result.")
          .foregroundStyle(.secondary)
      }
    } header: {
      Text("Result")
    } footer: {
      Text(TerminalCopy.disclaimer)
    }
  }

  private var aiSection: some View {
    Section {
      if billingManager.isPro {
        aiButtons
      } else {
        Button {
          isPaywallPresented = true
        } label: {
          Label("Unlock AI fill with Pro", systemImage: "lock.fill")
        }
      }
      if let message = model.aiMessage {
        Text(message)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      if let facts = model.shareFacts {
        shareFactsCard(facts)
      }
      if let suggestion = model.scenarioSuggestion {
        scenarioCard(suggestion)
      }
    } header: {
      Text("AI assist")
    } footer: {
      Text("Suggestions come with sources and are never saved until you tap Save.")
    }
  }

  private var aiButtons: some View {
    HStack {
      Button {
        Task { await model.fillWithAI() }
      } label: {
        Label("Fill with AI", systemImage: "sparkles")
      }
      .disabled(model.isFetchingShareFacts)
      Spacer()
      Button {
        Task { await model.suggestScenario() }
      } label: {
        Label("Suggest scenario", systemImage: "wand.and.stars")
      }
      .disabled(model.isFetchingScenario)
    }
    .buttonStyle(.bordered)
    .overlay {
      if model.isFetchingShareFacts || model.isFetchingScenario {
        ProgressView()
      }
    }
  }

  private func shareFactsCard(_ facts: ShareFactsSuggestion) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("AI suggestion")
        .font(.subheadline.weight(.semibold))
      if let shares = facts.sharesOutstanding {
        LabeledContent("Shares outstanding") { Text(TerminalFormat.count(shares)) }
      }
      if let price = facts.currentSharePrice {
        LabeledContent("Share price") {
          Text(TerminalFormat.price(price, currency: facts.currency ?? model.currency))
        }
      }
      if let asOf = facts.asOf {
        Text("As of \(asOf)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if let note = model.shareFactsCurrencyNote {
        Text(note)
          .font(.caption)
          .foregroundStyle(.orange)
      }
      TerminalSourcesList(sources: facts.sources)
      HStack {
        Button("Accept") { model.acceptShareFacts() }
          .buttonStyle(.borderedProminent)
        Button("Dismiss") { model.dismissShareFacts() }
          .buttonStyle(.bordered)
      }
    }
  }

  private func scenarioCard(_ suggestion: TerminalScenarioSuggestion) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("AI scenario")
        .font(.subheadline.weight(.semibold))
      LabeledContent("Future share count") { Text(TerminalFormat.count(suggestion.terminalShareCount)) }
      LabeledContent("Future market cap") {
        Text(TerminalFormat.money(suggestion.terminalMarketCap, currency: model.currency))
      }
      Text("Horizon: \(suggestion.horizonYears) years")
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(verbatim: suggestion.rationale)
        .font(.footnote)
      TerminalSourcesList(sources: suggestion.sources)
      HStack {
        Button("Accept") { model.acceptScenario() }
          .buttonStyle(.borderedProminent)
        Button("Dismiss") { model.dismissScenario() }
          .buttonStyle(.bordered)
      }
    }
  }

  private func problemText(_ text: String) -> some View {
    Text(text)
      .font(.caption)
      .foregroundStyle(.red)
  }

  private func save() async {
    guard let saved = await model.save() else { return }
    onSaved(saved)
    dismiss()
  }
}
