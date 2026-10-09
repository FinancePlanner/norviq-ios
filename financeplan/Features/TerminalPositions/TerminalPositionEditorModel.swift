import Foundation
import Observation
import StockPlanShared

@MainActor @Observable
final class TerminalPositionEditorModel {
  enum Field: Hashable {
    case ticker, terminalShareCount, terminalMarketCap, valueWanted, sharesOwned, sharesOutstanding, currentSharePrice
  }

  /// Everything the form holds. An edit is compared with what was loaded by
  /// typed text, not by floating point, so an untouched field is never re-sent.
  struct Inputs: Equatable {
    var ticker: String
    var terminalShareCount: TerminalNumberInput
    var terminalMarketCap: TerminalNumberInput
    var valueWanted: TerminalNumberInput
    var sharesOwned: TerminalNumberInput
    var sharesOutstanding: TerminalNumberInput
    var currentSharePrice: TerminalNumberInput
    var notes: String
  }

  private struct Values {
    let ticker: String
    let terminalShareCount: Double
    let terminalMarketCap: Double
    let valueWanted: Double
    let sharesOwned: Double?
    let sharesOutstanding: Double?
    let currentSharePrice: Double?
    let notes: String?
  }

  private static let noChanges = TerminalPositionUpdateRequest(
    ticker: nil, sharesOutstanding: nil, terminalShareCount: nil, terminalMarketCap: nil,
    valueWanted: nil, sharesOwned: nil, currentSharePrice: nil, notes: nil, clear: nil
  )

  let original: TerminalPositionResponse?
  let currency: String
  var inputs: Inputs
  var isSaving = false
  var errorMessage: String?
  private(set) var shareFacts: ShareFactsSuggestion?
  private(set) var scenarioSuggestion: TerminalScenarioSuggestion?
  private(set) var isFetchingShareFacts = false
  private(set) var isFetchingScenario = false
  private(set) var aiMessage: String?
  /// Set when the server answers with the Pro gate; the sheet shows the paywall.
  var needsUpgrade = false

  private let initialInputs: Inputs
  private let service: any TerminalPositionsServicing
  private let locale: Locale

  init(
    position: TerminalPositionResponse? = nil,
    ticker: String? = nil,
    currency: String,
    service: any TerminalPositionsServicing,
    locale: Locale = .current
  ) {
    original = position
    self.currency = currency
    self.service = service
    self.locale = locale
    let inputs = Inputs(
      ticker: position?.ticker ?? ticker?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? "",
      terminalShareCount: TerminalNumberInput(value: position?.terminalShareCount, locale: locale),
      terminalMarketCap: TerminalNumberInput(value: position?.terminalMarketCap, locale: locale),
      valueWanted: TerminalNumberInput(value: position?.valueWanted, locale: locale),
      sharesOwned: TerminalNumberInput(value: position.map(\.sharesOwned), usesUnits: false, locale: locale),
      sharesOutstanding: TerminalNumberInput(value: position?.sharesOutstanding, locale: locale),
      currentSharePrice: TerminalNumberInput(value: position?.currentSharePrice, usesUnits: false, locale: locale),
      notes: position?.notes ?? ""
    )
    self.inputs = inputs
    initialInputs = inputs
  }

  var isEditing: Bool {
    original != nil
  }

  var normalizedTicker: String {
    inputs.ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
  }

  var isTickerValid: Bool {
    normalizedTicker.range(of: #"^[A-Z0-9.\-]{1,12}$"#, options: .regularExpression) != nil
  }

  func problem(for field: Field) -> String? {
    switch field {
    case .ticker:
      return inputs.ticker.isEmpty || isTickerValid ? nil : String(
        localized: "Use 1–12 letters, digits, dots or dashes."
      )
    case .terminalShareCount:
      return positiveProblem(inputs.terminalShareCount, message: String(localized: "Share count must be above zero."))
    case .terminalMarketCap:
      return positiveProblem(inputs.terminalMarketCap, message: String(localized: "Market cap must be above zero."))
    case .valueWanted:
      return nonNegativeProblem(inputs.valueWanted)
    case .sharesOwned:
      return nonNegativeProblem(inputs.sharesOwned)
    case .sharesOutstanding:
      return positiveProblem(inputs.sharesOutstanding, message: String(localized: "Must be above zero."))
    case .currentSharePrice:
      return positiveProblem(inputs.currentSharePrice, message: String(localized: "Must be above zero."))
    }
  }

  /// The backend refuses notes over 1,000 characters.
  static let maxNotesLength = 1_000

  var notesProblem: String? {
    inputs.notes.trimmingCharacters(in: .whitespacesAndNewlines).count > Self.maxNotesLength
      ? String(localized: "Use 1,000 characters or fewer.")
      : nil
  }

  /// The shared maths on what is typed now. Nil until the three required
  /// fields read as numbers.
  var preview: Result<TerminalScenarioResult, TerminalScenarioError>? {
    guard
      let shareCount = inputs.terminalShareCount.value(locale: locale),
      let marketCap = inputs.terminalMarketCap.value(locale: locale),
      let valueWanted = inputs.valueWanted.value(locale: locale),
      let sharesOwned = optionalValue(inputs.sharesOwned),
      let price = optionalValue(inputs.currentSharePrice)
    else { return nil }
    return TerminalMath.evaluate(TerminalScenarioInput(
      terminalShareCount: shareCount,
      terminalMarketCap: marketCap,
      valueWanted: valueWanted,
      sharesOwned: sharesOwned ?? 0,
      currentSharePrice: price
    ))
  }

  var previewResult: TerminalScenarioResult? {
    if case let .success(result)? = preview {
      return result
    }
    return nil
  }

  var canSave: Bool {
    !isSaving && values() != nil
  }

  static func text(for error: TerminalScenarioError) -> String {
    switch error {
    case .shareCountNotPositive: String(localized: "Share count must be above zero.")
    case .marketCapNotPositive: String(localized: "Market cap must be above zero.")
    case .invalidNumber: String(localized: "These numbers can't be used. Check for negatives.")
    }
  }

  /// For a row's `scenarioError`, which may carry a raw value newer than this build.
  static func text(forRaw raw: String) -> String {
    TerminalScenarioError(rawValue: raw).map { text(for: $0) }
      ?? String(localized: "This scenario needs a positive share count and market cap.")
  }

  func makeCreateRequest() -> TerminalPositionCreateRequest? {
    guard let values = values() else { return nil }
    return TerminalPositionCreateRequest(
      ticker: values.ticker,
      sharesOutstanding: values.sharesOutstanding,
      terminalShareCount: values.terminalShareCount,
      terminalMarketCap: values.terminalMarketCap,
      valueWanted: values.valueWanted,
      sharesOwned: values.sharesOwned,
      currentSharePrice: values.currentSharePrice,
      notes: values.notes
    )
  }

  /// Only the fields the user touched. A cleared optional goes in `clear`,
  /// because the PATCH reads a missing key as "leave it".
  func makeUpdateRequest() -> TerminalPositionUpdateRequest? {
    guard let original, let values = values() else { return nil }
    let start = initialInputs
    var clear: [String] = []

    func changed<T>(_ keyPath: KeyPath<Inputs, TerminalNumberInput>, _ value: T) -> T? {
      inputs[keyPath: keyPath] == start[keyPath: keyPath] ? nil : value
    }

    func optional(_ keyPath: KeyPath<Inputs, TerminalNumberInput>, _ value: Double?, key: String) -> Double? {
      guard inputs[keyPath: keyPath] != start[keyPath: keyPath] else { return nil }
      if value == nil {
        clear.append(key)
      }
      return value
    }

    let sharesOutstanding = optional(\.sharesOutstanding, values.sharesOutstanding, key: "sharesOutstanding")
    let currentSharePrice = optional(\.currentSharePrice, values.currentSharePrice, key: "currentSharePrice")
    var notes: String?
    if inputs.notes != start.notes {
      if let newNotes = values.notes {
        notes = newNotes
      } else {
        clear.append("notes")
      }
    }

    return TerminalPositionUpdateRequest(
      ticker: values.ticker == original.ticker ? nil : values.ticker,
      sharesOutstanding: sharesOutstanding,
      terminalShareCount: changed(\.terminalShareCount, values.terminalShareCount),
      terminalMarketCap: changed(\.terminalMarketCap, values.terminalMarketCap),
      valueWanted: changed(\.valueWanted, values.valueWanted),
      sharesOwned: changed(\.sharesOwned, values.sharesOwned ?? 0),
      currentSharePrice: currentSharePrice,
      notes: notes,
      clear: clear.isEmpty ? nil : clear
    )
  }

  func save() async -> TerminalPositionResponse? {
    guard canSave else { return nil }
    isSaving = true
    defer { isSaving = false }
    do {
      if let original {
        guard let request = makeUpdateRequest() else { return nil }
        if request == Self.noChanges {
          return original
        }
        return try await service.update(id: original.id, request)
      }
      guard let request = makeCreateRequest() else { return nil }
      return try await service.create(request)
    } catch {
      errorMessage = TerminalPositionsErrorText.message(
        for: error,
        fallback: String(localized: "The position could not be saved."),
        // A 404 on create means the route is missing, not a deleted row.
        notFound: isEditing
          ? String(localized: "This row was deleted on another device.")
          : String(localized: "Terminal positions are unavailable right now.")
      )
      return nil
    }
  }

  // MARK: - AI (Pro). Suggestions only: Accept fills fields, Save writes.

  func fillWithAI() async {
    guard isTickerValid else {
      aiMessage = String(localized: "Enter a ticker first.")
      return
    }
    aiMessage = nil
    shareFacts = nil
    isFetchingShareFacts = true
    defer { isFetchingShareFacts = false }
    do {
      shareFacts = try await service.shareFacts(ticker: normalizedTicker)
    } catch {
      handleAIError(error)
    }
  }

  func suggestScenario() async {
    guard isTickerValid else {
      aiMessage = String(localized: "Enter a ticker first.")
      return
    }
    aiMessage = nil
    scenarioSuggestion = nil
    isFetchingScenario = true
    defer { isFetchingScenario = false }
    do {
      scenarioSuggestion = try await service.suggestScenario(ticker: normalizedTicker, horizonYears: nil)
    } catch {
      handleAIError(error)
    }
  }

  /// Fills shares outstanding and today's price, never the market cap or the
  /// value wanted, and never saves.
  func acceptShareFacts() {
    guard let facts = shareFacts else { return }
    // Numbers fetched for another ticker are never filled in.
    guard facts.ticker.uppercased() == normalizedTicker else {
      shareFacts = nil
      return
    }
    if let shares = facts.sharesOutstanding {
      inputs.sharesOutstanding = TerminalNumberInput(value: shares, locale: locale)
    }
    if let price = facts.currentSharePrice {
      inputs.currentSharePrice = TerminalNumberInput(value: price, usesUnits: false, locale: locale)
    }
    shareFacts = nil
  }

  /// Fills the future share count and market cap. Never saves.
  func acceptScenario() {
    guard let suggestion = scenarioSuggestion else { return }
    guard suggestion.ticker.uppercased() == normalizedTicker else {
      scenarioSuggestion = nil
      return
    }
    inputs.terminalShareCount = TerminalNumberInput(value: suggestion.terminalShareCount, locale: locale)
    inputs.terminalMarketCap = TerminalNumberInput(value: suggestion.terminalMarketCap, locale: locale)
    scenarioSuggestion = nil
  }

  func dismissShareFacts() { shareFacts = nil }

  func dismissScenario() { scenarioSuggestion = nil }

  /// The lookup can quote a listing in another currency than the plan's.
  var shareFactsCurrencyNote: String? {
    guard let suggested = shareFacts?.currency?.uppercased(), !suggested.isEmpty,
          suggested != currency.uppercased()
    else { return nil }
    let planCurrency = currency.uppercased()
    return String(localized: "This price is in \(suggested); your plan uses \(planCurrency).")
  }

  private func handleAIError(_ error: Error) {
    if TerminalPositionsErrorText.isCancellation(error) { return }
    switch error as? TerminalPositionsHTTPClient.Error {
    case .upgradeRequired?:
      needsUpgrade = true
    case .rejected(status: 503, message: _)?:
      aiMessage = String(localized: "AI lookup is unavailable right now. You can still enter the numbers yourself.")
    case .rejected(status: 422, message: _)?:
      aiMessage = String(localized: "The AI couldn't find usable numbers for this ticker.")
    case .rejected(status: 429, message: _)?:
      aiMessage = String(localized: "Too many AI lookups. Try again in a minute.")
    default:
      aiMessage = String(localized: "The AI lookup failed. Try again.")
    }
  }

  // MARK: - Private

  /// Every field read, the ticker valid and the scenario valid; otherwise nil.
  private func values() -> Values? {
    guard
      isTickerValid,
      notesProblem == nil,
      problem(for: .sharesOutstanding) == nil,
      problem(for: .currentSharePrice) == nil,
      previewResult != nil,
      let shareCount = inputs.terminalShareCount.value(locale: locale),
      let marketCap = inputs.terminalMarketCap.value(locale: locale),
      let valueWanted = inputs.valueWanted.value(locale: locale),
      let sharesOwned = optionalValue(inputs.sharesOwned),
      let sharesOutstanding = optionalValue(inputs.sharesOutstanding),
      let price = optionalValue(inputs.currentSharePrice)
    else { return nil }
    let notes = inputs.notes.trimmingCharacters(in: .whitespacesAndNewlines)
    return Values(
      ticker: normalizedTicker,
      terminalShareCount: shareCount,
      terminalMarketCap: marketCap,
      valueWanted: valueWanted,
      sharesOwned: sharesOwned,
      sharesOutstanding: sharesOutstanding,
      currentSharePrice: price,
      notes: notes.isEmpty ? nil : notes
    )
  }

  /// `.some(nil)` for an empty optional field; nil when it can't be read.
  private func optionalValue(_ input: TerminalNumberInput) -> Double?? {
    switch input.reading(locale: locale) {
    case .empty: .some(nil)
    case let .value(value): .some(value)
    case .invalid, .negative: nil
    }
  }

  private func positiveProblem(_ input: TerminalNumberInput, message: String) -> String? {
    switch input.reading(locale: locale) {
    case .empty: nil
    case .invalid: String(localized: "Enter a number.")
    case .negative: message
    case let .value(value): value > 0 ? nil : message
    }
  }

  private func nonNegativeProblem(_ input: TerminalNumberInput) -> String? {
    switch input.reading(locale: locale) {
    case .empty, .value: nil
    case .invalid: String(localized: "Enter a number.")
    case .negative: String(localized: "Can't be negative.")
    }
  }
}
